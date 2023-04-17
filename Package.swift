// swift-tools-version: 5.6

import PackageDescription

import Foundation
var supported_frameworks: [LinkerSetting] = []
#if canImport(AVFoundation)
supported_frameworks.append(.linkedFramework("AVFoundation"))
#endif
#if canImport(AppKit)
supported_frameworks.append(.linkedFramework("AppKit"))
#endif
#if canImport(AudioToolbox)
supported_frameworks.append(.linkedFramework("AudioToolbox"))
#endif
#if canImport(AudioUnit)
supported_frameworks.append(.linkedFramework("AudioUnit"))
#endif
#if canImport(CoreAudio)
supported_frameworks.append(.linkedFramework("CoreAudio"))
#endif
#if canImport(CoreGraphics)
supported_frameworks.append(.linkedFramework("CoreGraphics"))
#endif
#if canImport(CoreMedia)
supported_frameworks.append(.linkedFramework("CoreMedia"))
#endif
#if canImport(CoreServices)
supported_frameworks.append(.linkedFramework("CoreServices"))
#endif
#if canImport(CoreVideo)
supported_frameworks.append(.linkedFramework("CoreVideo"))
#endif
#if canImport(Foundation)
supported_frameworks.append(.linkedFramework("Foundation"))
#endif
#if canImport(QuartzCore)
supported_frameworks.append(.linkedFramework("QuartzCore"))
#endif
#if canImport(VideoToolbox)
supported_frameworks.append(.linkedFramework("VideoToolbox"))
#endif

let pathRoot = URL(fileURLWithPath: #file).deletingLastPathComponent()
let pathConfigure = URL(fileURLWithPath: "configure-spm", relativeTo: pathRoot)
let pathConfigSpm = URL(fileURLWithPath: "pjlib/include/pj/config_spm.h", relativeTo: pathRoot)
let pathConfigSite = URL(fileURLWithPath: "pjlib/include/pj/config_site.h", relativeTo: pathRoot)

let configureDisable = [ "android-mediacodec", "bcg729", "ffmpeg", "g722-codec", "g7221-codec", "gsm-codec", "ilbc-codec", "l16-codec", "libwebrtc", "opencore-amr", "opus", "pjsua2", "silk", "speex-aec", "speex-codec", "upnp", "v4l2", "vpx" ]
let configureEnable = ["epoll", "kqueue"]

let pathCp = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":").map { URL(fileURLWithPath: "cp", relativeTo: URL(fileURLWithPath: String($0))) }.filter { (try? $0.checkResourceIsReachable()) ?? false }.first

print(pathCp?.absoluteURL.path)
print(pathConfigSpm.absoluteURL.path)
print(pathConfigSite.absoluteURL.path)

print(pathConfigure.absoluteURL.path)
print(configureDisable.map { "--disable-\($0)" } + configureEnable.map { "--enable-\($0)" })

try? Process.run(pathConfigure, arguments: configureDisable.map { "--disable-\($0)" } + configureEnable.map { "--enable-\($0)" })

if let pathCp = pathCp {
    try? Process.run(pathCp, arguments: ["\(pathConfigSpm)", "\(pathConfigSite)"])
}

ProcessInfo.processInfo.environment.forEach { (k,v) in
    print("env \(k) = \(v)")
}

ProcessInfo.processInfo.arguments.forEach { arg in
    print("arg \(arg)")
}

let pjprojectDebug = ProcessInfo.processInfo.environment.keys.contains(where: { $0 == "PJPROJECT_DEBUG" }) ?? false
let pjprojectDebugLib = ProcessInfo.processInfo.environment["PJPROJECT_DEBUG_LIB"] ?? ""

//
//if let envPath = ProcessInfo.processInfo.environment["PATH"] {
//    envPath.split(separator: ":").map { path in
//        let maybeCp =
//        if let cp = try? maybeCp.checkResourceIsReachable() {
//            print(maybeCp.path)
//        }
//    }
//}
//exit(0)
//pjlib/include/pj/config_site.h

// Process.run(configure, arguments: configure_disable.map { "--disable-\($0)" } + configure_enable.map { "--enable-\($0)" })

let packagePath = #file

var pjproject_lib_prefixes = [ "pjmedia", "pjmedia-audiodev", "pjmedia-codec", "pjsdp", "pjmedia-videodev", "pjsip-simple", "pjsip", "pjsua", "pjsip-ua", "pj", "pjlib-util", "resample", "srtp", "yuv", "pjnath" ]

extension URL {
    func fileIsRelativeOf(relativeTo: URL) -> Bool {
        let ancestorComponents: [String] = relativeTo.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        let childComponents: [String] = self.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        return (ancestorComponents.count <= childComponents.count) && (!zip(ancestorComponents, childComponents).contains(where: !=))
    }
    func fileUrlRelativeTo(relativeTo: URL) -> URL? {
        let ancestorComponents: [String] = relativeTo.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        let childComponents: [String] = self.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        let isChild = (ancestorComponents.count <= childComponents.count) && (!zip(ancestorComponents, childComponents).contains(where: !=))
        if isChild {
            return URL(fileURLWithPath: childComponents[ancestorComponents.count...].map({ String($0) }).joined(separator: "/"), relativeTo: relativeTo)
        }
        return nil
    }
    func sourceFile() -> URL? {
        let newSource = ["c", "cpp", "m", "cc"].map { e in
            self.deletingPathExtension().appendingPathExtension(e)
        }.first { source in
            if let r = try? source.checkResourceIsReachable() {
                return r
            }
            return false
        }
        return newSource
    }
}

struct LibOptions {
    let libs: [String]?
    var libsSettings: [LinkerSetting] {
        self.libs?.map { (l) in LinkerSetting.linkedLibrary(l) } ?? []
    }

    var libLocal: [String]? { self.libs?.filter { lib in !pjproject_lib_prefixes.filter { lib.starts(with: $0) }.isEmpty } }
    var libLocalSettings: [LinkerSetting] {
        self.libLocal?.map { (l) in LinkerSetting.linkedLibrary(l) } ?? []
    }

    var libNonLocal: [String]? { self.libs?.filter { lib in pjproject_lib_prefixes.filter { lib.starts(with: $0) }.isEmpty } }
    var libNonLocalSettings: [LinkerSetting] {
        self.libNonLocal?.map { (l) in LinkerSetting.linkedLibrary(l) } ?? []
    }

    let frameworks: [String]?
    var frameworksSettings: [LinkerSetting] { self.frameworks?.map { (l) in LinkerSetting.linkedFramework(l) } ?? [] }

    let search: [String]?
    func searchSettings(fileRelativeTo: URL, resultRelativeTo: URL, packageRootUrl: URL) -> [LinkerSetting] {

        let resultUrls = self.search?.map { item in
            let itemUrl = URL(fileURLWithPath: item, isDirectory: true, relativeTo: fileRelativeTo)
            return itemUrl.fileUrlRelativeTo(relativeTo: resultRelativeTo)
        }

        if (resultUrls?.count ?? 0) > 0 {
            return [LinkerSetting.unsafeFlags(resultUrls!.filter { $0 != nil }.map{ $0! }.filter{ $0.fileIsRelativeOf(relativeTo: packageRootUrl) != true }.map { "-L\($0.resolvingSymlinksInPath().path)" })]
        }
        return []
    }

    let others: [String]?
    var othersSettings: [LinkerSetting] { [LinkerSetting.unsafeFlags(self.others ?? [])] }


}
protocol CDefinesProtocol<DefinesSettingsType> {
    associatedtype DefinesSettingsType
    var noValue: [String]? { get set }
    var noValueSettings: [DefinesSettingsType] { get }

    var asZero: [String]? { get set }
    var asZeroSettings: [DefinesSettingsType] { get }

    var asOne: [String]? { get set }
    var asOneSettings: [DefinesSettingsType] { get }

    var others: [(String, String)]? { get set }
    var othersSettings: [DefinesSettingsType] { get }

    var settings: [DefinesSettingsType] { get }


}

extension CDefinesProtocol  {
    var settings: [DefinesSettingsType] {
        return noValueSettings + asZeroSettings + asOneSettings + othersSettings
    }
}
protocol CDefinesProtocolCSetting : CDefinesProtocol where DefinesSettingsType == CSetting {

}

protocol CDefinesProtocolCXXSetting : CDefinesProtocol where DefinesSettingsType == CXXSetting {

}
extension CDefinesProtocolCSetting {
    var noValueSettings: [DefinesSettingsType] { self.noValue?.map { (k) in DefinesSettingsType.define(k) } ?? [] }
    var asZeroSettings: [DefinesSettingsType] { self.asZero?.map { (k) in DefinesSettingsType.define(k, to: "0") } ?? [] }
    var asOneSettings: [DefinesSettingsType] { self.asOne?.map { (k) in DefinesSettingsType.define(k, to: "1") } ?? [] }
    var othersSettings: [DefinesSettingsType] { self.others?.map { (k, v) in DefinesSettingsType.define(k, to: v) } ?? [] }
}

extension CDefinesProtocolCXXSetting {
    var noValueSettings: [CXXSetting] { self.noValue?.map { (k) in CXXSetting.define(k) } ?? [] }
    var asZeroSettings: [CXXSetting] { self.asZero?.map { (k) in CXXSetting.define(k, to: "0") } ?? [] }
    var asOneSettings: [CXXSetting] { self.asOne?.map { (k) in CXXSetting.define(k, to: "1") } ?? [] }
    var othersSettings: [CXXSetting] { self.others?.map { (k, v) in CXXSetting.define(k, to: v) } ?? [] }
}

struct CDefines : CDefinesProtocolCSetting {
    typealias DefinesSettingsType = CSetting
    var noValue: [String]?
    var asZero: [String]?
    var asOne: [String]?
    var others: [(String, String)]?
}

struct CXXDefines : CDefinesProtocolCXXSetting {
    typealias DefinesSettingsType = CXXSetting
    var noValue: [String]?
    var asZero: [String]?
    var asOne: [String]?
    var others: [(String, String)]?
}

protocol CSettingsOrCXXSettings {

}

protocol COptionsProtocol {
    associatedtype SettingsType
    var definesSettings: [SettingsType] { get }

    var includes: [String]? { get set }
    func includesSettings(repoRoot: URL, fileRelativeTo: URL, resultRelativeTo: URL) -> [SettingsType]

    var others: [String]? { get set }
    var othersSettings: [SettingsType] { get }
}
protocol COptionsProtocolCSetting : COptionsProtocol where SettingsType == CSetting {
    var defines: CDefines { get set }
}

protocol COptionsProtocolCXXSetting : COptionsProtocol where SettingsType == CXXSetting {
    var defines: CXXDefines { get set }
}

struct COptions : COptionsProtocolCSetting {
    typealias SettingsType = CSetting

    var defines: CDefines
    var definesSettings: [SettingsType] { defines.noValueSettings + defines.asZeroSettings + defines.asOneSettings + defines.othersSettings }

    var includes: [String]?
    func includesSettings(repoRoot: URL, fileRelativeTo: URL, resultRelativeTo: URL) -> [SettingsType] {
        
        let includesUrls: [URL?]? = self.includes?.map { (item: String) -> String in
            if item.starts(with: "/path/to/pjsip/pjproject/") {
                var repoRootString = repoRoot.standardizedFileURL.resolvingSymlinksInPath().absoluteURL.path
                return "\(repoRootString)/\(item[item.index(item.startIndex, offsetBy: 25)...])"
            } else {
                return item
            }
        }.map { (item: String) -> URL? in
            let itemUrl = URL(fileURLWithPath: item, isDirectory: true, relativeTo: fileRelativeTo)
            return itemUrl.fileUrlRelativeTo(relativeTo: resultRelativeTo)
        }
        return (includesUrls ?? []).filter { $0 != nil }.map { SettingsType.headerSearchPath($0!.relativeString) }
    }

    var others: [String]?
    var othersSettings: [SettingsType] { if (self.others != nil) { return [SettingsType.unsafeFlags(self.others!)] } else { return [] } }

    func cSettings(repoRoot: URL, fileRelativeTo: URL, resultRelativeTo: URL) -> [CSetting] {


        return self.definesSettings + self.includesSettings(repoRoot: repoRoot, fileRelativeTo: fileRelativeTo, resultRelativeTo: resultRelativeTo)
    }
}

struct CXXOptions : COptionsProtocolCXXSetting {
    typealias SettingsType = CXXSetting
    var defines: CXXDefines
    var definesSettings: [SettingsType] { defines.noValueSettings + defines.asZeroSettings + defines.asOneSettings + defines.othersSettings }

    var includes: [String]?
    func includesSettings(repoRoot: URL, fileRelativeTo: URL, resultRelativeTo: URL) -> [SettingsType] {
        
        let includesUrls: [URL?]? = self.includes?.map { (item: String) -> String in
            if item.starts(with: "/path/to/pjsip/pjproject/") {
                var repoRootString = repoRoot.standardizedFileURL.resolvingSymlinksInPath().absoluteURL.path
                return "\(repoRootString)/\(item[item.index(item.startIndex, offsetBy: 25)...])"
            } else {
                return item
            }
        }.map { (item: String) -> URL? in
            let itemUrl = URL(fileURLWithPath: item, isDirectory: true, relativeTo: fileRelativeTo)
            return itemUrl.fileUrlRelativeTo(relativeTo: resultRelativeTo)
        }
        return (includesUrls ?? []).filter { $0 != nil }.map { SettingsType.headerSearchPath($0!.relativeString) }
    }

    var others: [String]?
    var othersSettings: [SettingsType] { if (self.others != nil) { return [SettingsType.unsafeFlags(self.others!)] } else { return [] } }
}

struct MakePaths {
    let package: String = #file
    let makefile: String
    let source: String
    var packageUrl: URL {
        return URL(fileURLWithPath: self.package)
    }
    var packageRootUrl: URL? {
        return self.packageUrl.deletingLastPathComponent()
    }
    var makefileUrl: URL {
        URL(fileURLWithPath: self.makefile, relativeTo: packageRootUrl)
    }
    var sourceUrl: URL {
        URL(fileURLWithPath: self.source, relativeTo: self.makefileUrl)
    }
}

struct MakePackage {
    let name: String
    let paths: MakePaths
    let c: COptions
    let cxx: CXXOptions
    let ld: LibOptions
    let objects: [String]
    var objectFileUrls: [URL] {
        self.objects.map { obj in
            URL(fileURLWithPath: obj, relativeTo: self.paths.sourceUrl)
        }
    }
    var sourceFileUrls: [URL?] {
        return self.objectFileUrls.map { $0.sourceFile() }
    }
    func cSettings(resultRelativeTo: URL) -> [CSetting] {
        return self.c.definesSettings + self.c.includesSettings(repoRoot: self.paths.packageRootUrl!, fileRelativeTo: self.paths.makefileUrl, resultRelativeTo: resultRelativeTo)
    }
    func cxxSettings(resultRelativeTo: URL) -> [CXXSetting] {
        return self.cxx.definesSettings + self.cxx.includesSettings(repoRoot: self.paths.packageRootUrl!, fileRelativeTo: self.paths.makefileUrl, resultRelativeTo: resultRelativeTo)
    }
    func linkerSettings(libsRelativeTo: URL, resultRelativeTo: URL, packageRootUrl: URL) -> [LinkerSetting] {
        // return self.ld.libNonLocalSettings + self.ld.frameworksSettings + self.ld.othersSettings + self.ld.searchSettings(fileRelativeTo: libsRelativeTo, resultRelativeTo: resultRelativeTo, packageRootUrl: packageRootUrl)
        return self.ld.libNonLocalSettings + self.ld.frameworksSettings + self.ld.othersSettings
    }

    func makeTarget(packagePath: String, buildDir: String, searchRoot: String, publicHeadersPath: String?, dependencies: [Target.Dependency] = [], extraCSettings: [CSetting] = [], extraCxxSettings: [CXXSetting] = [], extraLinkerSettings: [LinkerSetting] = []) -> Target {
        let buildDirUrl = URL(fileURLWithPath: buildDir, relativeTo: paths.packageRootUrl)
        let searchRootUrl = URL(fileURLWithPath: searchRoot, relativeTo: paths.packageRootUrl)
        let packagePathUrl = URL(fileURLWithPath: packagePath, relativeTo: paths.packageRootUrl)

        let cSettings = self.cSettings(resultRelativeTo: packagePathUrl)+extraCSettings
        let cxxSettings = self.cxxSettings(resultRelativeTo: packagePathUrl)+extraCxxSettings

        let sources = self.sourceFileUrls.filter { $0 != nil }.map { $0!.fileUrlRelativeTo(relativeTo: packagePathUrl)!.relativeString }

        let linkerSettings = self.linkerSettings(libsRelativeTo: searchRootUrl, resultRelativeTo: packagePathUrl, packageRootUrl: paths.packageRootUrl!)+extraLinkerSettings

        var excludes: [String] = []
        if packagePath == "." {
            excludes = [ "pjsip-apps" ]
        }

        if pjprojectDebug {
            if pjprojectDebugLib.isEmpty || pjprojectDebugLib == name {
                print("!! \(name) buildDirUrl: \(buildDirUrl)")
                print("!! \(name) buildDirUrl resolved: \(buildDirUrl.resolvingSymlinksInPath().absoluteURL.path)")
                print("!! \(name) searchRootUrl: \(searchRootUrl)")
                print("!! \(name) searchRootUrl resolved: \(searchRootUrl.resolvingSymlinksInPath().absoluteURL.path)")
                print("!! \(name) packagePathUrl: \(packagePathUrl)")
                print("!! \(name) packagePathUrl resolved: \(packagePathUrl.resolvingSymlinksInPath().absoluteURL.path)")
                print("!! \(name) makefileUrl: \(self.paths.makefileUrl)")
                print("!! \(name) makefileUrl resolved: \(self.paths.makefileUrl.resolvingSymlinksInPath().absoluteURL.path)")

                print("!! \(name) includesSettings:")
                self.c.includesSettings(repoRoot: self.paths.packageRootUrl!, fileRelativeTo: self.paths.makefileUrl, resultRelativeTo: packagePathUrl.absoluteURL).forEach { print($0) }

                print("!! \(name) c.includes:")
                c.includes?.forEach { print($0) }

                print("!! \(name) cSettings:")
                cSettings.forEach { print($0) }

                print("!! \(name) cxxSettings:")
                cxxSettings.forEach { print($0) }

                print("!! \(name) sources:")
                sources.forEach { print($0) }

                print("!! \(name) linkerSettings:")
                linkerSettings.forEach { print($0) }
            }
        }


        return Target.target(
            name: self.name,
            dependencies: dependencies,
            path: packagePathUrl.relativeString,
            exclude: excludes,
            sources: sources,
            resources: [],
            publicHeadersPath: publicHeadersPath,
            cSettings: cSettings,
            cxxSettings: cxxSettings,
            linkerSettings: linkerSettings
        )
    }
}


let make_pjlib = MakePackage(
    name: "pjlib",
    paths: MakePaths(makefile: "pjlib/build", source: "../src/pj"),
    c: COptions(
        defines: CDefines(
            noValue: [],
            asZero: ["PJ_IS_BIG_ENDIAN"],
            asOne: ["PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: []
        ),
        includes: ["../include"],
        others: ["-Wall", "-fPIC"]
    ),
    cxx: CXXOptions(
        defines: CXXDefines(
            noValue: [],
            asZero: ["PJ_IS_BIG_ENDIAN"],
            asOne: ["PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: []
        ),
        includes: ["../include"],
        others: ["-Wall", "-fPIC"]
    ),
    ld: LibOptions(
        libs: ["SDL2", "gnutls", "m", "openh264", "pthread", "stdc++"],
        frameworks: ["AVFoundation", "AppKit", "AudioToolbox", "AudioUnit", "CoreAudio", "CoreGraphics", "CoreMedia", "CoreServices", "CoreVideo", "Foundation", "QuartzCore", "VideoToolbox"],
        search: ["../pjlib-util/lib", "../pjlib/lib", "../pjmedia/lib", "../pjnath/lib", "../pjsip/lib", "../third_party/lib"/*, "/opt/homebrew/Cellar/gnutls/3.8.0/lib", "/opt/homebrew/lib"*/],
        others: []
    ),
    objects: ["ioqueue_kqueue.o", "file_access_unistd.o", "file_io_ansi.o", "os_core_unix.o", "os_error_unix.o", "os_time_unix.o", "os_timestamp_posix.o", "os_core_darwin.o", "sock_qos_darwin.o", "sock_qos_bsd.o", "ssl_sock_apple.o", "guid_darwin.o", "addr_resolv_sock.o", "log_writer_stdout.o", "os_timestamp_common.o", "pool_policy_malloc.o", "sock_bsd.o", "sock_select.o", "activesock.o", "array.o", "config.o", "ctype.o", "errno.o", "except.o", "fifobuf.o", "guid.o", "hash.o", "ip_helper_generic.o", "list.o", "lock.o", "log.o", "os_time_common.o", "os_info.o", "pool.o", "pool_buf.o", "pool_caching.o", "pool_dbg.o", "rand.o", "rbtree.o", "sock_common.o", "sock_qos_common.o", "ssl_sock_common.o", "ssl_sock_ossl.o", "ssl_sock_gtls.o", "ssl_sock_dump.o", "ssl_sock_darwin.o", "string.o", "timer.o", "types.o"]
)
let make_pjlib_util = MakePackage(
    name: "pjlib_util",
    paths: MakePaths(makefile: "pjlib-util/build", source: "../src/pjlib-util"),
    c: COptions(
        defines: CDefines(
            noValue: [],
            asZero: ["PJ_IS_BIG_ENDIAN"],
            asOne: ["PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: []
        ),
        includes: ["../../pjlib/include", "../include"],
        others: ["-Wall", "-fPIC"]
    ),
    cxx: CXXOptions(
        defines: CXXDefines(
            noValue: [],
            asZero: ["PJ_IS_BIG_ENDIAN"],
            asOne: ["PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: []
        ),
        includes: ["../../pjlib/include", "../include"],
        others: ["-Wall", "-fPIC"]
    ),
    ld: LibOptions(
        libs: ["SDL2", "gnutls", "m", "openh264", "pj-arm-apple-darwin22.4.0", "pthread", "stdc++"],
        frameworks: ["AVFoundation", "AppKit", "AudioToolbox", "AudioUnit", "CoreAudio", "CoreGraphics", "CoreMedia", "CoreServices", "CoreVideo", "Foundation", "QuartzCore", "VideoToolbox"],
        search: ["../pjlib-util/lib", "../pjlib/lib", "../pjmedia/lib", "../pjnath/lib", "../pjsip/lib", "../third_party/lib"/*, "/opt/homebrew/Cellar/gnutls/3.8.0/lib", "/opt/homebrew/lib"*/],
        others: []
    ),
    objects: ["base64.o", "cli.o", "cli_console.o", "cli_telnet.o", "crc32.o", "errno.o", "dns.o", "dns_dump.o", "dns_server.o", "getopt.o", "hmac_md5.o", "hmac_sha1.o", "http_client.o", "json.o", "md5.o", "pcap.o", "resolver.o", "scanner.o", "sha1.o", "srv_resolver.o", "string.o", "stun_simple.o", "stun_simple_client.o", "xml.o"]
)
let make_pjsip = MakePackage(
    name: "pjsip",
    paths: MakePaths(makefile: "pjsip/build", source: "../src/pjsip"),
    c: COptions(
        defines: CDefines(
            noValue: [],
            asZero: ["PJ_IS_BIG_ENDIAN"],
            asOne: ["PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: []
        ),
        includes: ["../../pjlib-util/include", "../../pjlib/include", "../../pjmedia/include", "../../pjnath/include", "../include"],
        others: ["-Wall", "-fPIC"]
    ),
    cxx: CXXOptions(
        defines: CXXDefines(
            noValue: [],
            asZero: ["PJ_IS_BIG_ENDIAN"],
            asOne: ["PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: []
        ),
        includes: ["../../pjlib-util/include", "../../pjlib/include", "../../pjmedia/include", "../../pjnath/include", "../include"],
        others: ["-Wall", "-fPIC"]
    ),
    ld: LibOptions(
        libs: ["SDL2", "gnutls", "m", "openh264", "pj-arm-apple-darwin22.4.0", "pjlib-util-arm-apple-darwin22.4.0", "pthread", "resample-arm-apple-darwin22.4.0", "srtp-arm-apple-darwin22.4.0", "stdc++", "yuv-arm-apple-darwin22.4.0"],
        frameworks: ["AVFoundation", "AppKit", "AudioToolbox", "AudioUnit", "CoreAudio", "CoreGraphics", "CoreMedia", "CoreServices", "CoreVideo", "Foundation", "QuartzCore", "VideoToolbox"],
        search: ["../pjlib-util/lib", "../pjlib/lib", "../pjmedia/lib", "../pjnath/lib", "../pjsip/lib", "../third_party/lib", "/opt/homebrew/Cellar/gnutls/3.8.0/lib", "/opt/homebrew/lib"],
        others: []
    ),
    objects: ["sip_config.o", "sip_multipart.o", "sip_errno.o", "sip_msg.o", "sip_parser.o", "sip_tel_uri.o", "sip_uri.o", "sip_endpoint.o", "sip_util.o", "sip_util_proxy.o", "sip_resolve.o", "sip_transport.o", "sip_transport_loop.o", "sip_transport_udp.o", "sip_transport_tcp.o", "sip_transport_tls.o", "sip_auth_aka.o", "sip_auth_client.o", "sip_auth_msg.o", "sip_auth_parser.o", "sip_auth_server.o", "sip_transaction.o", "sip_util_statefull.o", "sip_dialog.o", "sip_ua_layer.o"]
)
let make_pjsip_simple = MakePackage(
    name: "pjsip_simple",
    paths: MakePaths(makefile: "pjsip/build", source: "../src/pjsip-simple"),
    c: COptions(
        defines: CDefines(
            noValue: [],
            asZero: ["PJ_IS_BIG_ENDIAN"],
            asOne: ["PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: []
        ),
        includes: ["../../pjlib-util/include", "../../pjlib/include", "../../pjmedia/include", "../../pjnath/include", "../include"],
        others: ["-Wall", "-fPIC"]
    ),
    cxx: CXXOptions(
        defines: CXXDefines(
            noValue: [],
            asZero: ["PJ_IS_BIG_ENDIAN"],
            asOne: ["PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: []
        ),
        includes: ["../../pjlib-util/include", "../../pjlib/include", "../../pjmedia/include", "../../pjnath/include", "../include"],
        others: ["-Wall", "-fPIC"]
    ),
    ld: LibOptions(
        libs: ["SDL2", "gnutls", "m", "openh264", "pj-arm-apple-darwin22.4.0", "pjlib-util-arm-apple-darwin22.4.0", "pjsip-arm-apple-darwin22.4.0", "pthread", "resample-arm-apple-darwin22.4.0", "srtp-arm-apple-darwin22.4.0", "stdc++", "yuv-arm-apple-darwin22.4.0"],
        frameworks: ["AVFoundation", "AppKit", "AudioToolbox", "AudioUnit", "CoreAudio", "CoreGraphics", "CoreMedia", "CoreServices", "CoreVideo", "Foundation", "QuartzCore", "VideoToolbox"],
        search: ["../pjlib-util/lib", "../pjlib/lib", "../pjmedia/lib", "../pjnath/lib", "../pjsip/lib", "../third_party/lib", "/opt/homebrew/Cellar/gnutls/3.8.0/lib", "/opt/homebrew/lib"],
        others: []
    ),
    objects: ["errno.o", "evsub.o", "evsub_msg.o", "iscomposing.o", "mwi.o", "pidf.o", "presence.o", "presence_body.o", "publishc.o", "rpid.o", "xpidf.o"]
)
let make_pjsip_ua = MakePackage(
    name: "pjsip_ua",
    paths: MakePaths(makefile: "pjsip/build", source: "../src/pjsip-ua"),
    c: COptions(
        defines: CDefines(
            noValue: [],
            asZero: ["PJ_IS_BIG_ENDIAN"],
            asOne: ["PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: []
        ),
        includes: ["../../pjlib-util/include", "../../pjlib/include", "../../pjmedia/include", "../../pjnath/include", "../include"],
        others: ["-Wall", "-fPIC"]
    ),
    cxx: CXXOptions(
        defines: CXXDefines(
            noValue: [],
            asZero: ["PJ_IS_BIG_ENDIAN"],
            asOne: ["PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: []
        ),
        includes: ["../../pjlib-util/include", "../../pjlib/include", "../../pjmedia/include", "../../pjnath/include", "../include"],
        others: ["-Wall", "-fPIC"]
    ),
    ld: LibOptions(
        libs: ["SDL2", "gnutls", "m", "openh264", "pj-arm-apple-darwin22.4.0", "pjlib-util-arm-apple-darwin22.4.0", "pjmedia-arm-apple-darwin22.4.0", "pjsip-arm-apple-darwin22.4.0", "pjsip-simple-arm-apple-darwin22.4.0", "pthread", "resample-arm-apple-darwin22.4.0", "srtp-arm-apple-darwin22.4.0", "stdc++", "yuv-arm-apple-darwin22.4.0"],
        frameworks: ["AVFoundation", "AppKit", "AudioToolbox", "AudioUnit", "CoreAudio", "CoreGraphics", "CoreMedia", "CoreServices", "CoreVideo", "Foundation", "QuartzCore", "VideoToolbox"],
        search: ["../pjlib-util/lib", "../pjlib/lib", "../pjmedia/lib", "../pjnath/lib", "../pjsip/lib", "../third_party/lib", "/opt/homebrew/Cellar/gnutls/3.8.0/lib", "/opt/homebrew/lib"],
        others: []
    ),
    objects: ["sip_inv.o", "sip_reg.o", "sip_replaces.o", "sip_xfer.o", "sip_100rel.o", "sip_timer.o"]
)
let make_pjnath = MakePackage(
    name: "pjnath",
    paths: MakePaths(makefile: "pjnath/build", source: "../src/pjnath"),
    c: COptions(
        defines: CDefines(
            noValue: [],
            asZero: ["PJ_IS_BIG_ENDIAN"],
            asOne: ["PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: []
        ),
        includes: ["../../pjlib-util/include", "../../pjlib/include", "../include"],
        others: ["-Wall", "-fPIC"]
    ),
    cxx: CXXOptions(
        defines: CXXDefines(
            noValue: [],
            asZero: ["PJ_IS_BIG_ENDIAN"],
            asOne: ["PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: []
        ),
        includes: ["../../pjlib-util/include", "../../pjlib/include", "../include"],
        others: ["-Wall", "-fPIC"]
    ),
    ld: LibOptions(
        libs: ["SDL2", "gnutls", "m", "openh264", "pj-arm-apple-darwin22.4.0", "pjlib-util-arm-apple-darwin22.4.0", "pthread", "stdc++"],
        frameworks: ["AVFoundation", "AppKit", "AudioToolbox", "AudioUnit", "CoreAudio", "CoreGraphics", "CoreMedia", "CoreServices", "CoreVideo", "Foundation", "QuartzCore", "VideoToolbox"],
        search: ["../pjlib-util/lib", "../pjlib/lib", "../pjmedia/lib", "../pjnath/lib", "../pjsip/lib", "../third_party/lib", "/opt/homebrew/Cellar/gnutls/3.8.0/lib", "/opt/homebrew/lib"],
        others: []
    ),
    objects: ["errno.o", "ice_session.o", "ice_strans.o", "nat_detect.o", "stun_auth.o", "stun_msg.o", "stun_msg_dump.o", "stun_session.o", "stun_sock.o", "stun_transaction.o", "turn_session.o", "turn_sock.o", "upnp.o"]
)
let make_pjmedia = MakePackage(
    name: "pjmedia",
    paths: MakePaths(makefile: "pjmedia/build", source: "../src/pjmedia"),
    c: COptions(
        defines: CDefines(
            noValue: ["_THREAD_SAFE"],
            asZero: ["PJMEDIA_AUDIO_DEV_HAS_PORTAUDIO", "PJMEDIA_AUDIO_DEV_HAS_WMME", "PJMEDIA_HAS_ANDROID_MEDIACODEC", "PJMEDIA_HAS_G7221_CODEC", "PJMEDIA_HAS_G722_CODEC", "PJMEDIA_HAS_GSM_CODEC", "PJMEDIA_HAS_ILBC_CODEC", "PJMEDIA_HAS_L16_CODEC", "PJMEDIA_HAS_OPENCORE_AMRNB_CODEC", "PJMEDIA_HAS_OPENCORE_AMRWB_CODEC", "PJMEDIA_HAS_SPEEX_AEC", "PJMEDIA_HAS_SPEEX_CODEC", "PJMEDIA_HAS_WEBRTC_AEC", "PJMEDIA_HAS_WEBRTC_AEC3", "PJ_IS_BIG_ENDIAN"],
            asOne: ["PJMEDIA_AUDIO_DEV_HAS_COREAUDIO", "PJMEDIA_HAS_LIBYUV", "PJMEDIA_HAS_OPENH264_CODEC", "PJMEDIA_VIDEO_DEV_HAS_DARWIN", "PJMEDIA_VIDEO_DEV_HAS_SDL", "PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: [("PJMEDIA_RESAMPLE_IMP", "PJMEDIA_RESAMPLE_LIBRESAMPLE")]
        ),
        includes: ["../..", "../../pjlib-util/include", "../../pjlib/include", "../../pjmedia/include", "../../pjnath/include", "../include", "/path/to/pjsip/pjproject/third_party/build/srtp", "/path/to/pjsip/pjproject/third_party/srtp/crypto/include", "/path/to/pjsip/pjproject/third_party/srtp/include", "/path/to/pjsip/pjproject/third_party/yuv/include", "/opt/homebrew/include/SDL2"],
        others: ["-Wall", "-fPIC"]
    ),
    cxx: CXXOptions(
        defines: CXXDefines(
            noValue: ["_THREAD_SAFE"],
            asZero: ["PJMEDIA_AUDIO_DEV_HAS_PORTAUDIO", "PJMEDIA_AUDIO_DEV_HAS_WMME", "PJMEDIA_HAS_ANDROID_MEDIACODEC", "PJMEDIA_HAS_G7221_CODEC", "PJMEDIA_HAS_G722_CODEC", "PJMEDIA_HAS_GSM_CODEC", "PJMEDIA_HAS_ILBC_CODEC", "PJMEDIA_HAS_L16_CODEC", "PJMEDIA_HAS_OPENCORE_AMRNB_CODEC", "PJMEDIA_HAS_OPENCORE_AMRWB_CODEC", "PJMEDIA_HAS_SPEEX_AEC", "PJMEDIA_HAS_SPEEX_CODEC", "PJMEDIA_HAS_WEBRTC_AEC", "PJMEDIA_HAS_WEBRTC_AEC3", "PJ_IS_BIG_ENDIAN"],
            asOne: ["PJMEDIA_AUDIO_DEV_HAS_COREAUDIO", "PJMEDIA_HAS_LIBYUV", "PJMEDIA_HAS_OPENH264_CODEC", "PJMEDIA_VIDEO_DEV_HAS_DARWIN", "PJMEDIA_VIDEO_DEV_HAS_SDL", "PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: [("PJMEDIA_RESAMPLE_IMP", "PJMEDIA_RESAMPLE_LIBRESAMPLE")]
        ),
        includes: ["../..", "../../pjlib-util/include", "../../pjlib/include", "../../pjmedia/include", "../../pjnath/include", "../include", "/path/to/pjsip/pjproject/third_party/build/srtp", "/path/to/pjsip/pjproject/third_party/srtp/crypto/include", "/path/to/pjsip/pjproject/third_party/srtp/include", "/path/to/pjsip/pjproject/third_party/yuv/include", "/opt/homebrew/include/SDL2"],
        others: ["-Wall", "-fPIC"]
    ),
    ld: LibOptions(
        libs: ["SDL2", "gnutls", "m", "openh264", "pj-arm-apple-darwin22.4.0", "pjlib-util-arm-apple-darwin22.4.0", "pjnath-arm-apple-darwin22.4.0", "pthread", "resample-arm-apple-darwin22.4.0", "srtp-arm-apple-darwin22.4.0", "stdc++", "yuv-arm-apple-darwin22.4.0"],
        frameworks: ["AVFoundation", "AppKit", "AudioToolbox", "AudioUnit", "CoreAudio", "CoreGraphics", "CoreMedia", "CoreServices", "CoreVideo", "Foundation", "QuartzCore", "VideoToolbox"],
        search: ["../pjlib-util/lib", "../pjlib/lib", "../pjmedia/lib", "../pjnath/lib", "../pjsip/lib", "../third_party/lib", "/opt/homebrew/Cellar/gnutls/3.8.0/lib", "/opt/homebrew/lib"],
        others: []
    ),
    objects: ["alaw_ulaw.o", "alaw_ulaw_table.o", "avi_player.o", "bidirectional.o", "clock_thread.o", "codec.o", "conference.o", "conf_switch.o", "converter.o", "converter_libswscale.o", "converter_libyuv.o", "delaybuf.o", "echo_common.o", "echo_port.o", "echo_suppress.o", "echo_webrtc.o", "echo_webrtc_aec3.o", "endpoint.o", "errno.o", "event.o", "format.o", "ffmpeg_util.o", "g711.o", "jbuf.o", "master_port.o", "mem_capture.o", "mem_player.o", "null_port.o", "plc_common.o", "port.o", "splitcomb.o", "resample_resample.o", "resample_libsamplerate.o", "resample_speex.o", "resample_port.o", "rtcp.o", "rtcp_xr.o", "rtcp_fb.o", "rtp.o", "sdp.o", "sdp_cmp.o", "sdp_neg.o", "session.o", "silencedet.o", "sound_legacy.o", "sound_port.o", "stereo_port.o", "stream_common.o", "stream.o", "stream_info.o", "tonegen.o", "transport_adapter_sample.o", "transport_ice.o", "transport_loop.o", "transport_srtp.o", "transport_udp.o", "types.o", "vid_codec.o", "vid_codec_util.o", "vid_port.o", "vid_stream.o", "vid_stream_info.o", "vid_conf.o", "wav_player.o", "wav_playlist.o", "wav_writer.o", "wave.o", "wsola.o", "audiodev.o", "videodev.o"]
)
let make_pjmedia_videodev = MakePackage(
    name: "pjmedia_videodev",
    paths: MakePaths(makefile: "pjmedia/build", source: "../src/pjmedia-videodev"),
    c: COptions(
        defines: CDefines(
            noValue: ["_THREAD_SAFE"],
            asZero: ["PJMEDIA_AUDIO_DEV_HAS_PORTAUDIO", "PJMEDIA_AUDIO_DEV_HAS_WMME", "PJMEDIA_HAS_ANDROID_MEDIACODEC", "PJMEDIA_HAS_G7221_CODEC", "PJMEDIA_HAS_G722_CODEC", "PJMEDIA_HAS_GSM_CODEC", "PJMEDIA_HAS_ILBC_CODEC", "PJMEDIA_HAS_L16_CODEC", "PJMEDIA_HAS_OPENCORE_AMRNB_CODEC", "PJMEDIA_HAS_OPENCORE_AMRWB_CODEC", "PJMEDIA_HAS_SPEEX_AEC", "PJMEDIA_HAS_SPEEX_CODEC", "PJMEDIA_HAS_WEBRTC_AEC", "PJMEDIA_HAS_WEBRTC_AEC3", "PJ_IS_BIG_ENDIAN"],
            asOne: ["PJMEDIA_AUDIO_DEV_HAS_COREAUDIO", "PJMEDIA_HAS_LIBYUV", "PJMEDIA_HAS_OPENH264_CODEC", "PJMEDIA_VIDEO_DEV_HAS_DARWIN", "PJMEDIA_VIDEO_DEV_HAS_SDL", "PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: [("PJMEDIA_RESAMPLE_IMP", "PJMEDIA_RESAMPLE_LIBRESAMPLE")]
        ),
        includes: ["../..", "../../pjlib-util/include", "../../pjlib/include", "../../pjmedia/include", "../../pjnath/include", "../include", "/path/to/pjsip/pjproject/third_party/build/srtp", "/path/to/pjsip/pjproject/third_party/srtp/crypto/include", "/path/to/pjsip/pjproject/third_party/srtp/include", "/path/to/pjsip/pjproject/third_party/yuv/include", "/opt/homebrew/include/SDL2"],
        others: ["-Wall", "-fPIC"]
    ),
    cxx: CXXOptions(
        defines: CXXDefines(
            noValue: ["_THREAD_SAFE"],
            asZero: ["PJMEDIA_AUDIO_DEV_HAS_PORTAUDIO", "PJMEDIA_AUDIO_DEV_HAS_WMME", "PJMEDIA_HAS_ANDROID_MEDIACODEC", "PJMEDIA_HAS_G7221_CODEC", "PJMEDIA_HAS_G722_CODEC", "PJMEDIA_HAS_GSM_CODEC", "PJMEDIA_HAS_ILBC_CODEC", "PJMEDIA_HAS_L16_CODEC", "PJMEDIA_HAS_OPENCORE_AMRNB_CODEC", "PJMEDIA_HAS_OPENCORE_AMRWB_CODEC", "PJMEDIA_HAS_SPEEX_AEC", "PJMEDIA_HAS_SPEEX_CODEC", "PJMEDIA_HAS_WEBRTC_AEC", "PJMEDIA_HAS_WEBRTC_AEC3", "PJ_IS_BIG_ENDIAN"],
            asOne: ["PJMEDIA_AUDIO_DEV_HAS_COREAUDIO", "PJMEDIA_HAS_LIBYUV", "PJMEDIA_HAS_OPENH264_CODEC", "PJMEDIA_VIDEO_DEV_HAS_DARWIN", "PJMEDIA_VIDEO_DEV_HAS_SDL", "PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: [("PJMEDIA_RESAMPLE_IMP", "PJMEDIA_RESAMPLE_LIBRESAMPLE")]
        ),
        includes: ["../..", "../../pjlib-util/include", "../../pjlib/include", "../../pjmedia/include", "../../pjnath/include", "../include", "/path/to/pjsip/pjproject/third_party/build/srtp", "/path/to/pjsip/pjproject/third_party/srtp/crypto/include", "/path/to/pjsip/pjproject/third_party/srtp/include", "/path/to/pjsip/pjproject/third_party/yuv/include", "/opt/homebrew/include/SDL2"],
        others: ["-Wall", "-fPIC"]
    ),
    ld: LibOptions(
        libs: ["SDL2", "gnutls", "m", "openh264", "pj-arm-apple-darwin22.4.0", "pjmedia-arm-apple-darwin22.4.0", "pthread", "resample-arm-apple-darwin22.4.0", "srtp-arm-apple-darwin22.4.0", "stdc++", "yuv-arm-apple-darwin22.4.0"],
        frameworks: ["AVFoundation", "AppKit", "AudioToolbox", "AudioUnit", "CoreAudio", "CoreGraphics", "CoreMedia", "CoreServices", "CoreVideo", "Foundation", "QuartzCore", "VideoToolbox"],
        search: ["../pjlib-util/lib", "../pjlib/lib", "../pjmedia/lib", "../pjnath/lib", "../pjsip/lib", "../third_party/lib", "/opt/homebrew/Cellar/gnutls/3.8.0/lib", "/opt/homebrew/lib"],
        others: []
    ),
    objects: ["darwin_dev.o", "sdl_dev_m.o", "videodev.o", "errno.o", "avi_dev.o", "ffmpeg_dev.o", "colorbar_dev.o", "v4l2_dev.o", "opengl_dev.o", "util.o"]
)
let make_pjmedia_audiodev = MakePackage(
    name: "pjmedia_audiodev",
    paths: MakePaths(makefile: "pjmedia/build", source: "../src/pjmedia-audiodev"),
    c: COptions(
        defines: CDefines(
            noValue: ["_THREAD_SAFE"],
            asZero: ["PJMEDIA_AUDIO_DEV_HAS_PORTAUDIO", "PJMEDIA_AUDIO_DEV_HAS_WMME", "PJMEDIA_HAS_ANDROID_MEDIACODEC", "PJMEDIA_HAS_G7221_CODEC", "PJMEDIA_HAS_G722_CODEC", "PJMEDIA_HAS_GSM_CODEC", "PJMEDIA_HAS_ILBC_CODEC", "PJMEDIA_HAS_L16_CODEC", "PJMEDIA_HAS_OPENCORE_AMRNB_CODEC", "PJMEDIA_HAS_OPENCORE_AMRWB_CODEC", "PJMEDIA_HAS_SPEEX_AEC", "PJMEDIA_HAS_SPEEX_CODEC", "PJMEDIA_HAS_WEBRTC_AEC", "PJMEDIA_HAS_WEBRTC_AEC3", "PJ_IS_BIG_ENDIAN"],
            asOne: ["PJMEDIA_AUDIO_DEV_HAS_COREAUDIO", "PJMEDIA_HAS_LIBYUV", "PJMEDIA_HAS_OPENH264_CODEC", "PJMEDIA_VIDEO_DEV_HAS_DARWIN", "PJMEDIA_VIDEO_DEV_HAS_SDL", "PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: [("PJMEDIA_RESAMPLE_IMP", "PJMEDIA_RESAMPLE_LIBRESAMPLE")]
        ),
        includes: ["../..", "../../pjlib-util/include", "../../pjlib/include", "../../pjmedia/include", "../../pjnath/include", "../include", "/path/to/pjsip/pjproject/third_party/build/srtp", "/path/to/pjsip/pjproject/third_party/srtp/crypto/include", "/path/to/pjsip/pjproject/third_party/srtp/include", "/path/to/pjsip/pjproject/third_party/yuv/include", "/opt/homebrew/include/SDL2"],
        others: ["-Wall", "-fPIC"]
    ),
    cxx: CXXOptions(
        defines: CXXDefines(
            noValue: ["_THREAD_SAFE"],
            asZero: ["PJMEDIA_AUDIO_DEV_HAS_PORTAUDIO", "PJMEDIA_AUDIO_DEV_HAS_WMME", "PJMEDIA_HAS_ANDROID_MEDIACODEC", "PJMEDIA_HAS_G7221_CODEC", "PJMEDIA_HAS_G722_CODEC", "PJMEDIA_HAS_GSM_CODEC", "PJMEDIA_HAS_ILBC_CODEC", "PJMEDIA_HAS_L16_CODEC", "PJMEDIA_HAS_OPENCORE_AMRNB_CODEC", "PJMEDIA_HAS_OPENCORE_AMRWB_CODEC", "PJMEDIA_HAS_SPEEX_AEC", "PJMEDIA_HAS_SPEEX_CODEC", "PJMEDIA_HAS_WEBRTC_AEC", "PJMEDIA_HAS_WEBRTC_AEC3", "PJ_IS_BIG_ENDIAN"],
            asOne: ["PJMEDIA_AUDIO_DEV_HAS_COREAUDIO", "PJMEDIA_HAS_LIBYUV", "PJMEDIA_HAS_OPENH264_CODEC", "PJMEDIA_VIDEO_DEV_HAS_DARWIN", "PJMEDIA_VIDEO_DEV_HAS_SDL", "PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: [("PJMEDIA_RESAMPLE_IMP", "PJMEDIA_RESAMPLE_LIBRESAMPLE")]
        ),
        includes: ["../..", "../../pjlib-util/include", "../../pjlib/include", "../../pjmedia/include", "../../pjnath/include", "../include", "/path/to/pjsip/pjproject/third_party/build/srtp", "/path/to/pjsip/pjproject/third_party/srtp/crypto/include", "/path/to/pjsip/pjproject/third_party/srtp/include", "/path/to/pjsip/pjproject/third_party/yuv/include", "/opt/homebrew/include/SDL2"],
        others: ["-Wall", "-fPIC"]
    ),
    ld: LibOptions(
        libs: ["SDL2", "gnutls", "m", "openh264", "pj-arm-apple-darwin22.4.0", "pjmedia-arm-apple-darwin22.4.0", "pthread", "resample-arm-apple-darwin22.4.0", "srtp-arm-apple-darwin22.4.0", "stdc++", "yuv-arm-apple-darwin22.4.0"],
        frameworks: ["AVFoundation", "AppKit", "AudioToolbox", "AudioUnit", "CoreAudio", "CoreGraphics", "CoreMedia", "CoreServices", "CoreVideo", "Foundation", "QuartzCore", "VideoToolbox"],
        search: ["../pjlib-util/lib", "../pjlib/lib", "../pjmedia/lib", "../pjnath/lib", "../pjsip/lib", "../third_party/lib", "/opt/homebrew/Cellar/gnutls/3.8.0/lib", "/opt/homebrew/lib"],
        others: []
    ),
    objects: ["coreaudio_dev.o", "audiodev.o", "audiotest.o", "errno.o", "legacy_dev.o", "null_dev.o", "pa_dev.o", "wmme_dev.o", "alsa_dev.o", "bb10_dev.o", "bdimad_dev.o", "android_jni_dev.o", "opensl_dev.o", "oboe_dev.o"]
)
let make_pjmedia_codec = MakePackage(
    name: "pjmedia_codec",
    paths: MakePaths(makefile: "pjmedia/build", source: "../src/pjmedia-codec"),
    c: COptions(
        defines: CDefines(
            noValue: ["_THREAD_SAFE"],
            asZero: ["PJMEDIA_AUDIO_DEV_HAS_PORTAUDIO", "PJMEDIA_AUDIO_DEV_HAS_WMME", "PJMEDIA_HAS_ANDROID_MEDIACODEC", "PJMEDIA_HAS_G7221_CODEC", "PJMEDIA_HAS_G722_CODEC", "PJMEDIA_HAS_GSM_CODEC", "PJMEDIA_HAS_ILBC_CODEC", "PJMEDIA_HAS_L16_CODEC", "PJMEDIA_HAS_OPENCORE_AMRNB_CODEC", "PJMEDIA_HAS_OPENCORE_AMRWB_CODEC", "PJMEDIA_HAS_SPEEX_AEC", "PJMEDIA_HAS_SPEEX_CODEC", "PJMEDIA_HAS_WEBRTC_AEC", "PJMEDIA_HAS_WEBRTC_AEC3", "PJ_IS_BIG_ENDIAN"],
            asOne: ["PJMEDIA_AUDIO_DEV_HAS_COREAUDIO", "PJMEDIA_HAS_LIBYUV", "PJMEDIA_HAS_OPENH264_CODEC", "PJMEDIA_VIDEO_DEV_HAS_DARWIN", "PJMEDIA_VIDEO_DEV_HAS_SDL", "PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: [("PJMEDIA_RESAMPLE_IMP", "PJMEDIA_RESAMPLE_LIBRESAMPLE")]
        ),
        includes: ["../..", "../../pjlib-util/include", "../../pjlib/include", "../../pjmedia/include", "../../pjnath/include", "../include", "/path/to/pjsip/pjproject/third_party/build/srtp", "/path/to/pjsip/pjproject/third_party/srtp/crypto/include", "/path/to/pjsip/pjproject/third_party/srtp/include", "/path/to/pjsip/pjproject/third_party/yuv/include", "/opt/homebrew/include/SDL2"],
        others: ["-Wall", "-fPIC"]
    ),
    cxx: CXXOptions(
        defines: CXXDefines(
            noValue: ["_THREAD_SAFE"],
            asZero: ["PJMEDIA_AUDIO_DEV_HAS_PORTAUDIO", "PJMEDIA_AUDIO_DEV_HAS_WMME", "PJMEDIA_HAS_ANDROID_MEDIACODEC", "PJMEDIA_HAS_G7221_CODEC", "PJMEDIA_HAS_G722_CODEC", "PJMEDIA_HAS_GSM_CODEC", "PJMEDIA_HAS_ILBC_CODEC", "PJMEDIA_HAS_L16_CODEC", "PJMEDIA_HAS_OPENCORE_AMRNB_CODEC", "PJMEDIA_HAS_OPENCORE_AMRWB_CODEC", "PJMEDIA_HAS_SPEEX_AEC", "PJMEDIA_HAS_SPEEX_CODEC", "PJMEDIA_HAS_WEBRTC_AEC", "PJMEDIA_HAS_WEBRTC_AEC3", "PJ_IS_BIG_ENDIAN"],
            asOne: ["PJMEDIA_AUDIO_DEV_HAS_COREAUDIO", "PJMEDIA_HAS_LIBYUV", "PJMEDIA_HAS_OPENH264_CODEC", "PJMEDIA_VIDEO_DEV_HAS_DARWIN", "PJMEDIA_VIDEO_DEV_HAS_SDL", "PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: [("PJMEDIA_RESAMPLE_IMP", "PJMEDIA_RESAMPLE_LIBRESAMPLE")]
        ),
        includes: ["../..", "../../pjlib-util/include", "../../pjlib/include", "../../pjmedia/include", "../../pjnath/include", "../include", "/path/to/pjsip/pjproject/third_party/build/srtp", "/path/to/pjsip/pjproject/third_party/srtp/crypto/include", "/path/to/pjsip/pjproject/third_party/srtp/include", "/path/to/pjsip/pjproject/third_party/yuv/include", "/opt/homebrew/include/SDL2"],
        others: ["-Wall", "-fPIC"]
    ),
    ld: LibOptions(
        libs: ["SDL2", "gnutls", "m", "openh264", "pj-arm-apple-darwin22.4.0", "pjmedia-arm-apple-darwin22.4.0", "pthread", "resample-arm-apple-darwin22.4.0", "srtp-arm-apple-darwin22.4.0", "stdc++", "yuv-arm-apple-darwin22.4.0"],
        frameworks: ["AVFoundation", "AppKit", "AudioToolbox", "AudioUnit", "CoreAudio", "CoreGraphics", "CoreMedia", "CoreServices", "CoreVideo", "Foundation", "QuartzCore", "VideoToolbox"],
        search: ["../pjlib-util/lib", "../pjlib/lib", "../pjmedia/lib", "../pjnath/lib", "../pjsip/lib", "../third_party/lib", "/opt/homebrew/Cellar/gnutls/3.8.0/lib", "/opt/homebrew/lib"],
        others: []
    ),
    objects: ["audio_codecs.o", "ffmpeg_vid_codecs.o", "openh264.o", "h263_packetizer.o", "h264_packetizer.o", "vpx_packetizer.o", "ipp_codecs.o", "silk.o", "opus.o", "vid_toolbox.o", "g7221_sdp_match.o", "amr_sdp_match.o", "passthrough.o", "vpx.o"]
)

let make_srtp = MakePackage(
    name: "srtp",
    paths: MakePaths(makefile: "third_party/build/srtp", source: "../../srtp"),
    c: COptions(
        defines: CDefines(
            noValue: ["HAVE_CONFIG_H"],
            asZero: ["PJ_IS_BIG_ENDIAN"],
            asOne: ["PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: []
        ),
        includes: [".", "../../../pjlib/include", "../../srtp/crypto/include", "../../srtp/include"],
        others: ["-Wall", "-fPIC"]
    ),
    cxx: CXXOptions(
        defines: CXXDefines(
            noValue: [],
            asZero: ["PJ_IS_BIG_ENDIAN"],
            asOne: ["PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: []
        ),
        includes: [".", "../../../pjlib/include", "../../srtp/crypto/include", "../../srtp/include"],
        others: ["-Wall", "-fPIC"]
    ),
    ld: LibOptions(
        libs: ["SDL2", "gnutls", "m", "openh264", "pj-arm-apple-darwin22.4.0", "pthread", "stdc++"],
        frameworks: ["AVFoundation", "AppKit", "AudioToolbox", "AudioUnit", "CoreAudio", "CoreGraphics", "CoreMedia", "CoreServices", "CoreVideo", "Foundation", "QuartzCore", "VideoToolbox"],
        search: ["../pjlib-util/lib", "../pjlib/lib", "../pjmedia/lib", "../pjnath/lib", "../pjsip/lib", "../third_party/lib", "/opt/homebrew/Cellar/gnutls/3.8.0/lib", "/opt/homebrew/lib"],
        others: []
    ),
    objects: ["crypto/cipher/cipher.o", "crypto/cipher/null_cipher.o", "crypto/cipher/aes.o", "crypto/cipher/aes_icm.o", "crypto/hash/null_auth.o", "crypto/hash/auth.o", "crypto/hash/sha1.o", "crypto/hash/hmac.o", "crypto/math/datatypes.o", "crypto/math/stat.o", "crypto/kernel/crypto_kernel.o", "crypto/kernel/alloc.o", "crypto/kernel/key.o", "pjlib/srtp_err.o", "crypto/replay/rdb.o", "crypto/replay/rdbx.o", "crypto/replay/ut_sim.o", "srtp/srtp.o", "srtp/ekt.o"]
)
let make_ilbc = MakePackage(
    name: "ilbc",
    paths: MakePaths(makefile: "third_party/build/ilbc", source: "../../ilbc"),
    c: COptions(
        defines: CDefines(
            noValue: [],
            asZero: ["PJ_IS_BIG_ENDIAN"],
            asOne: ["PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: []
        ),
        includes: [".", "../../../pjlib/include", "../../ilbc"],
        others: ["-Wall", "-fPIC"]
    ),
    cxx: CXXOptions(
        defines: CXXDefines(
            noValue: [],
            asZero: ["PJ_IS_BIG_ENDIAN"],
            asOne: ["PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: []
        ),
        includes: [".", "../../../pjlib/include", "../../ilbc"],
        others: ["-Wall", "-fPIC"]
    ),
    ld: LibOptions(
        libs: ["SDL2", "gnutls", "m", "openh264", "pthread", "stdc++"],
        frameworks: ["AVFoundation", "AppKit", "AudioToolbox", "AudioUnit", "CoreAudio", "CoreGraphics", "CoreMedia", "CoreServices", "CoreVideo", "Foundation", "QuartzCore", "VideoToolbox"],
        search: ["/opt/homebrew/Cellar/gnutls/3.8.0/lib", "/opt/homebrew/lib"],
        others: []
    ),
    objects: ["FrameClassify.o", "LPCdecode.o", "LPCencode.o", "StateConstructW.o", "StateSearchW.o", "anaFilter.o", "constants.o", "createCB.o", "doCPLC.o", "enhancer.o", "filter.o", "gainquant.o", "getCBvec.o", "helpfun.o", "hpInput.o", "hpOutput.o", "iCBConstruct.o", "iCBSearch.o", "iLBC_decode.o", "iLBC_encode.o", "lsf.o", "packing.o", "syntFilter.o"]
)
let make_webrtc = MakePackage(
    name: "webrtc",
    paths: MakePaths(makefile: "third_party/build/webrtc", source: "../../webrtc/src/webrtc/"),
    c: COptions(
        defines: CDefines(
            noValue: [],
            asZero: ["PJ_IS_BIG_ENDIAN"],
            asOne: ["PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: []
        ),
        includes: [".", "../../../pjlib/include", "../../webrtc/src"],
        others: ["-Wall", "-fPIC"]
    ),
    cxx: CXXOptions(
        defines: CXXDefines(
            noValue: [],
            asZero: ["PJ_IS_BIG_ENDIAN"],
            asOne: ["PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: []
        ),
        includes: [".", "../../../pjlib/include", "../../webrtc/src"],
        others: ["-Wall", "-fPIC"]
    ),
    ld: LibOptions(
        libs: ["SDL2", "gnutls", "m", "openh264", "pthread", "stdc++"],
        frameworks: ["AVFoundation", "AppKit", "AudioToolbox", "AudioUnit", "CoreAudio", "CoreGraphics", "CoreMedia", "CoreServices", "CoreVideo", "Foundation", "QuartzCore", "VideoToolbox"],
        search: ["/opt/homebrew/Cellar/gnutls/3.8.0/lib", "/opt/homebrew/lib"],
        others: []
    ),
    objects: ["modules/audio_processing/aec/aec_core.o", "modules/audio_processing/aec/aec_rdft.o", "modules/audio_processing/aec/aec_resampler.o", "modules/audio_processing/aec/echo_cancellation.o", "modules/audio_processing/aecm/aecm_core.o", "modules/audio_processing/aecm/echo_control_mobile.o", "modules/audio_processing/ns/noise_suppression.o", "modules/audio_processing/ns/noise_suppression_x.o", "modules/audio_processing/ns/ns_core.o", "modules/audio_processing/ns/nsx_core.o", "modules/audio_processing/utility/delay_estimator_wrapper.o", "modules/audio_processing/utility/delay_estimator.o", "common_audio/fft4g.o", "common_audio/ring_buffer.o", "common_audio/signal_processing/complex_bit_reverse.o", "common_audio/signal_processing/complex_fft.o", "common_audio/signal_processing/copy_set_operations.o", "common_audio/signal_processing/cross_correlation.o", "common_audio/signal_processing/division_operations.o", "common_audio/signal_processing/downsample_fast.o", "common_audio/signal_processing/energy.o", "common_audio/signal_processing/get_scaling_square.o", "common_audio/signal_processing/min_max_operations.o", "common_audio/signal_processing/randomization_functions.o", "common_audio/signal_processing/real_fft.o", "common_audio/signal_processing/spl_init.o", "common_audio/signal_processing/spl_sqrt.o", "common_audio/signal_processing/spl_sqrt_floor.o", "common_audio/signal_processing/vector_scaling_operations.o"]
)
let make_resample = MakePackage(
    name: "resample",
    paths: MakePaths(makefile: "third_party/build/resample", source: "../../resample/src"),
    c: COptions(
        defines: CDefines(
            noValue: [],
            asZero: ["PJ_IS_BIG_ENDIAN"],
            asOne: ["PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: []
        ),
        includes: [".", "../../../pjlib/include", "../../resample/include"],
        others: ["-Wall", "-fPIC"]
    ),
    cxx: CXXOptions(
        defines: CXXDefines(
            noValue: [],
            asZero: ["PJ_IS_BIG_ENDIAN"],
            asOne: ["PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: []
        ),
        includes: [".", "../../../pjlib/include", "../../resample/include"],
        others: ["-Wall", "-fPIC"]
    ),
    ld: LibOptions(
        libs: ["SDL2", "gnutls", "m", "openh264", "pthread", "stdc++"],
        frameworks: ["AVFoundation", "AppKit", "AudioToolbox", "AudioUnit", "CoreAudio", "CoreGraphics", "CoreMedia", "CoreServices", "CoreVideo", "Foundation", "QuartzCore", "VideoToolbox"],
        search: ["/opt/homebrew/Cellar/gnutls/3.8.0/lib", "/opt/homebrew/lib"],
        others: []
    ),
    objects: ["resamplesubs.o"]
)
let make_yuv = MakePackage(
    name: "yuv",
    paths: MakePaths(makefile: "third_party/build/yuv", source: "../../yuv/source"),
    c: COptions(
        defines: CDefines(
            noValue: [],
            asZero: ["PJ_IS_BIG_ENDIAN"],
            asOne: ["PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: []
        ),
        includes: [".", "../../../pjlib/include", "../../yuv/include"],
        others: ["-Wall", "-Wno-memset-elt-size", "-Wno-pragmas", "-Wno-unknown-warning-option", "-fPIC", "-fno-strict-aliasing", "-fomit-frame-pointer"]
    ),
    cxx: CXXOptions(
        defines: CXXDefines(
            noValue: [],
            asZero: ["PJ_IS_BIG_ENDIAN"],
            asOne: ["PJ_AUTOCONF", "PJ_IS_LITTLE_ENDIAN"],
            others: []
        ),
        includes: [".", "../../../pjlib/include", "../../yuv/include"],
        others: ["-Wall", "-Wno-memset-elt-size", "-Wno-pragmas", "-Wno-unknown-warning-option", "-fPIC", "-fno-strict-aliasing", "-fomit-frame-pointer"]
    ),
    ld: LibOptions(
        libs: [],
        frameworks: [],
        search: [],
        others: []
    ),
    objects: ["compare.o", "compare_common.o", "compare_gcc.o", "compare_neon64.o", "compare_neon.o", "compare_win.o", "convert_argb.o", "convert.o", "convert_from_argb.o", "convert_from.o", "convert_jpeg.o", "convert_to_argb.o", "convert_to_i420.o", "cpu_id.o", "mjpeg_decoder.o", "mjpeg_validate.o", "planar_functions.o", "rotate_any.o", "rotate_argb.o", "rotate.o", "rotate_common.o", "rotate_gcc.o", "rotate_dspr2.o", "rotate_neon64.o", "rotate_neon.o", "rotate_win.o", "row_any.o", "row_common.o", "row_gcc.o", "row_dspr2.o", "row_neon64.o", "row_neon.o", "row_win.o", "scale_any.o", "scale_argb.o", "scale.o", "scale_common.o", "scale_gcc.o", "scale_dspr2.o", "scale_neon64.o", "scale_neon.o", "scale_win.o", "video_common.o"]
)



let target_pjproject: Target = Target.target(
    name: "pjproject",
    path: ".",

    sources: [
        "pjlib/src/pj/ioqueue_kqueue.c",
        "pjlib/src/pj/file_access_unistd.c",
        "pjlib/src/pj/file_io_ansi.c",
        "pjlib/src/pj/os_core_unix.c",
        "pjlib/src/pj/os_error_unix.c",
        "pjlib/src/pj/os_time_unix.c",
        "pjlib/src/pj/os_timestamp_posix.c",
        "pjlib/src/pj/os_core_darwin.m",
        "pjlib/src/pj/sock_qos_darwin.c",
        "pjlib/src/pj/sock_qos_bsd.c",
        "pjlib/src/pj/ssl_sock_apple.m",
        "pjlib/src/pj/guid_darwin.c",
        "pjlib/src/pj/addr_resolv_sock.c",
        "pjlib/src/pj/log_writer_stdout.c",
        "pjlib/src/pj/os_timestamp_common.c",
        "pjlib/src/pj/pool_policy_malloc.c",
        "pjlib/src/pj/sock_bsd.c",
        "pjlib/src/pj/sock_select.c",
        "pjlib/src/pj/activesock.c",
        "pjlib/src/pj/array.c",
        "pjlib/src/pj/config.c",
        "pjlib/src/pj/ctype.c",
        "pjlib/src/pj/errno.c",
        "pjlib/src/pj/except.c",
        "pjlib/src/pj/fifobuf.c",
        "pjlib/src/pj/guid.c",
        "pjlib/src/pj/hash.c",
        "pjlib/src/pj/ip_helper_generic.c",
        "pjlib/src/pj/list.c",
        "pjlib/src/pj/lock.c",
        "pjlib/src/pj/log.c",
        "pjlib/src/pj/os_time_common.c",
        "pjlib/src/pj/os_info.c",
        "pjlib/src/pj/pool.c",
        "pjlib/src/pj/pool_buf.c",
        "pjlib/src/pj/pool_caching.c",
        "pjlib/src/pj/pool_dbg.c",
        "pjlib/src/pj/rand.c",
        "pjlib/src/pj/rbtree.c",
        "pjlib/src/pj/sock_common.c",
        "pjlib/src/pj/sock_qos_common.c",
        "pjlib/src/pj/ssl_sock_common.c",
        "pjlib/src/pj/ssl_sock_ossl.c",
        "pjlib/src/pj/ssl_sock_gtls.c",
        "pjlib/src/pj/ssl_sock_dump.c",
        "pjlib/src/pj/ssl_sock_darwin.c",
        "pjlib/src/pj/string.c",
        "pjlib/src/pj/timer.c",
        "pjlib/src/pj/types.c",
        "pjlib-util/src/pjlib-util/base64.c",
        "pjlib-util/src/pjlib-util/cli.c",
        "pjlib-util/src/pjlib-util/cli_console.c",
        "pjlib-util/src/pjlib-util/cli_telnet.c",
        "pjlib-util/src/pjlib-util/crc32.c",
        "pjlib-util/src/pjlib-util/errno.c",
        "pjlib-util/src/pjlib-util/dns.c",
        "pjlib-util/src/pjlib-util/dns_dump.c",
        "pjlib-util/src/pjlib-util/dns_server.c",
        "pjlib-util/src/pjlib-util/getopt.c",
        "pjlib-util/src/pjlib-util/hmac_md5.c",
        "pjlib-util/src/pjlib-util/hmac_sha1.c",
        "pjlib-util/src/pjlib-util/http_client.c",
        "pjlib-util/src/pjlib-util/json.c",
        "pjlib-util/src/pjlib-util/md5.c",
        "pjlib-util/src/pjlib-util/pcap.c",
        "pjlib-util/src/pjlib-util/resolver.c",
        "pjlib-util/src/pjlib-util/scanner.c",
        "pjlib-util/src/pjlib-util/sha1.c",
        "pjlib-util/src/pjlib-util/srv_resolver.c",
        "pjlib-util/src/pjlib-util/string.c",
        "pjlib-util/src/pjlib-util/stun_simple.c",
        "pjlib-util/src/pjlib-util/stun_simple_client.c",
        "pjlib-util/src/pjlib-util/xml.c",
    ],
    //publicHeadersPath: ".",
    cSettings: [
        .define("PJ_IS_BIG_ENDIAN", to: "0"),
        .define("PJ_AUTOCONF", to: "1"),
        .define("PJ_IS_LITTLE_ENDIAN", to: "1"),
        .headerSearchPath("pjlib/include"),
        .headerSearchPath("pjlib-util/include")
    ]
//    linkerSettings: supported_frameworks
)

let target_pjlib2: Target = Target.target(
    name: "pjlib",
    path: "pjlib",

    sources: [
        "src/pj/ioqueue_kqueue.c",
        "src/pj/file_access_unistd.c",
        "src/pj/file_io_ansi.c",
        "src/pj/os_core_unix.c",
        "src/pj/os_error_unix.c",
        "src/pj/os_time_unix.c",
        "src/pj/os_timestamp_posix.c",
        "src/pj/os_core_darwin.m",
        "src/pj/sock_qos_darwin.c",
        "src/pj/sock_qos_bsd.c",
        "src/pj/ssl_sock_apple.m",
        "src/pj/guid_darwin.c",
        "src/pj/addr_resolv_sock.c",
        "src/pj/log_writer_stdout.c",
        "src/pj/os_timestamp_common.c",
        "src/pj/pool_policy_malloc.c",
        "src/pj/sock_bsd.c",
        "src/pj/sock_select.c",
        "src/pj/activesock.c",
        "src/pj/array.c",
        "src/pj/config.c",
        "src/pj/ctype.c",
        "src/pj/errno.c",
        "src/pj/except.c",
        "src/pj/fifobuf.c",
        "src/pj/guid.c",
        "src/pj/hash.c",
        "src/pj/ip_helper_generic.c",
        "src/pj/list.c",
        "src/pj/lock.c",
        "src/pj/log.c",
        "src/pj/os_time_common.c",
        "src/pj/os_info.c",
        "src/pj/pool.c",
        "src/pj/pool_buf.c",
        "src/pj/pool_caching.c",
        "src/pj/pool_dbg.c",
        "src/pj/rand.c",
        "src/pj/rbtree.c",
        "src/pj/sock_common.c",
        "src/pj/sock_qos_common.c",
        "src/pj/ssl_sock_common.c",
        "src/pj/ssl_sock_ossl.c",
        "src/pj/ssl_sock_gtls.c",
        "src/pj/ssl_sock_dump.c",
        "src/pj/ssl_sock_darwin.c",
        "src/pj/string.c",
        "src/pj/timer.c",
        "src/pj/types.c"
    ],
    publicHeadersPath: "include",
    cSettings: [
        .define("PJ_IS_BIG_ENDIAN", to: "0"),
        .define("PJ_AUTOCONF", to: "1"),
        .define("PJ_IS_LITTLE_ENDIAN", to: "1"),
        .headerSearchPath("include"),
    ]
//    linkerSettings: supported_frameworks
)

let target_pjlib_util2: Target = Target.target(
    name: "pjlib_util",
    path: "pjlib-util",

    sources: [
        "src/pjlib-util/base64.c",
        "src/pjlib-util/cli.c",
        "src/pjlib-util/cli_console.c",
        "src/pjlib-util/cli_telnet.c",
        "src/pjlib-util/crc32.c",
        "src/pjlib-util/errno.c",
        "src/pjlib-util/dns.c",
        "src/pjlib-util/dns_dump.c",
        "src/pjlib-util/dns_server.c",
        "src/pjlib-util/getopt.c",
        "src/pjlib-util/hmac_md5.c",
        "src/pjlib-util/hmac_sha1.c",
        "src/pjlib-util/http_client.c",
        "src/pjlib-util/json.c",
        "src/pjlib-util/md5.c",
        "src/pjlib-util/pcap.c",
        "src/pjlib-util/resolver.c",
        "src/pjlib-util/scanner.c",
        "src/pjlib-util/sha1.c",
        "src/pjlib-util/srv_resolver.c",
        "src/pjlib-util/string.c",
        "src/pjlib-util/stun_simple.c",
        "src/pjlib-util/stun_simple_client.c",
        "src/pjlib-util/xml.c",
    ],
    publicHeadersPath: "include",
    cSettings: [
        .define("PJ_IS_BIG_ENDIAN", to: "0"),
        .define("PJ_AUTOCONF", to: "1"),
        .define("PJ_IS_LITTLE_ENDIAN", to: "1"),
        .headerSearchPath("include")
    ]
//    linkerSettings: supported_frameworks
)
/*
let env = ProcessInfo.processInfo.environment
print(env)
env.forEach { (k, v) in
    print("env \(k)=\(v)")
}
let args = ProcessInfo.processInfo.arguments
args.forEach { (    v) in
    print("arg \(v)")
}
*/
let package = Package(
    name: "pjproject",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "pjlib", targets: ["pjlib"]),
        .library(name: "pjlib_util", targets: ["pjlib_util"]),
        .library(name: "pjnath", targets: ["pjnath"]),
        .library(name: "pjsip", targets: ["pjsip"]),
        .library(name: "pjsip_simple", targets: ["pjsip_simple"]),
        .library(name: "pjsip_ua", targets: ["pjsip_ua"]),
        .library(name: "pjmedia", targets: ["pjmedia"]),
        .library(name: "pjmedia_videodev", targets: ["pjmedia_videodev"]),
        .library(name: "pjmedia_audiodev", targets: ["pjmedia_audiodev"]),
        .library(name: "pjmedia_codec", targets: ["pjmedia_codec"]),
    ],
    targets: [
        make_pjlib.makeTarget(packagePath: ".", buildDir: "pjlib/build", searchRoot: "pjlib", publicHeadersPath: "pjlib/include", extraCSettings: [.unsafeFlags(["-fno-objc-arc"])]),
        make_pjlib_util.makeTarget(packagePath: ".", buildDir: "pjlib-util/build", searchRoot: "pjlib-util", publicHeadersPath: "pjlib-util/include", dependencies: ["pjlib"]),
        make_pjnath.makeTarget(packagePath: "pjnath", buildDir: "pjnath/build", searchRoot: "pjnath", publicHeadersPath: "include", dependencies: ["pjlib", "pjlib_util"]),
        make_pjsip.makeTarget(packagePath: "pjsip", buildDir: "pjsip/build", searchRoot: "pjsip", publicHeadersPath: "include", dependencies: ["pjlib", "pjlib_util", "pjsip_ua", "pjsip_simple"]),
        make_pjsip_simple.makeTarget(packagePath: "pjsip", buildDir: "pjsip/build", searchRoot: "pjsip", publicHeadersPath: "include", dependencies: ["pjlib", "pjlib_util"]),
        make_pjsip_ua.makeTarget(packagePath: "pjsip", buildDir: "pjsip/build", searchRoot: "pjsip", publicHeadersPath: "include", dependencies: ["pjlib", "pjlib_util", "pjmedia"]),
        make_pjmedia.makeTarget(packagePath: ".", buildDir: "pjmedia/build", searchRoot: "pjmedia", publicHeadersPath: "pjmedia/include", dependencies: ["pjlib", "pjlib_util", "srtp", "pjnath", "yuv", "resample"]),
        make_pjmedia_videodev.makeTarget(packagePath: ".", buildDir: "pjmedia/build", searchRoot: "pjmedia", publicHeadersPath: "pjmedia/include", dependencies: ["yuv", "pjmedia"], extraCSettings: [.unsafeFlags(["-fno-objc-arc"])]),
        make_pjmedia_audiodev.makeTarget(packagePath: "pjmedia", buildDir: "pjmedia/build", searchRoot: "pjmedia", publicHeadersPath: "include", dependencies: ["pjmedia"], extraCSettings: [.unsafeFlags(["-fno-objc-arc"])]),
        make_pjmedia_codec.makeTarget(packagePath: "pjmedia", buildDir: "pjmedia/build", searchRoot: "pjmedia", publicHeadersPath: "include", dependencies: ["pjlib"]),
        make_srtp.makeTarget(packagePath: "third_party", buildDir: "third_party/build/srtp", searchRoot: "third_party/srtp", publicHeadersPath: "srtp/include", dependencies: ["pjlib"]),
        make_resample.makeTarget(packagePath: "third_party", buildDir: "third_party/build/resample", searchRoot: "third_party", publicHeadersPath: "resample/include", dependencies: []),
        make_yuv.makeTarget(packagePath: "third_party", buildDir: "third_party/build/yuv", searchRoot: "third_party", publicHeadersPath: "yuv/include", dependencies: []),
    ]
)

