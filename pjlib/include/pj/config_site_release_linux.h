#define PJ_HAS_FLOATING_POINT 1

// pjsua settings (not important because we dont use pjsua?)
#define PJSUA_MAX_CALLS                     530

// sip settings
#define PJSIP_MAX_TSX_COUNT                 4030
#ifdef PJSIP_MAX_DIALOG_COUNT
#undef PJSIP_MAX_DIALOG_COUNT
#endif
#define PJSIP_MAX_DIALOG_COUNT              4030
#define PJSIP_MAX_TRANSPORTS 500

// audio settings
#define PJMEDIA_AUDIO_DEV_HAS_PORTAUDIO     0
#define PJMEDIA_AUDIO_DEV_HAS_WMME          0
//#define PJMEDIA_AUDIO_DEV_HAS_COREAUDIO     1
//#define PJMEDIA_VIDEO_DEV_HAS_DARWIN       1

// video settings
#define PJMEDIA_HAS_VIDEO 1
#define PJMEDIA_VIDEO_DEV_HAS_SDL 1
#define PJMEDIA_HAS_VID_TOOLBOX_CODEC 0
#define PJMEDIA_HAS_OPENH264_CODEC 1
#define PJMEDIA_VID_DEV_MAX_DRIVERS 530
#define PJMEDIA_VID_DEV_MAX_DEVS 1060
#define PJMEDIA_MAX_VIDEO_ENC_FRAME_SIZE 8294400*2

// sdp settings
#define PJMEDIA_SDP_NEG_PREFER_REMOTE_CODEC_ORDER 0
#define PJMEDIA_HAS_SRTP 1

// rtcp settings
#define PJMEDIA_STREAM_ENABLE_XR 1
#define PJMEDIA_HAS_RTCP_XR 1
#define PJMEDIA_RTCP_STAT_HAS_IPDV 1
#define PJMEDIA_RTCP_STAT_HAS_RAW_JITTER 1
#define PJMEDIA_RTCP_RX_SDES_BUF_LEN 128
#define PJ_DEBUG_MUTEX 0
//#define PJ_POOL_DEBUG 1

#define PJ_CONFIG_SPEED 1
// #define PJ_CONFIG_DEBUG 1
// #define PJ_CUSTOM_CONFIG_NO_THREADS 1

#ifdef PJ_CONFIG_SPEED
#   define PJ_SCANNER_USE_BITWISE       0
#   undef PJ_OS_HAS_CHECK_STACK
#   define PJ_OS_HAS_CHECK_STACK        0
#   undef PJ_IOQUEUE_MAX_HANDLES
#   define PJ_IOQUEUE_MAX_HANDLES       10240
#   undef FD_SETSIZE
#   define FD_SETSIZE                   10240
// #   define PJ_IOQUEUE_MAX_HANDLES       1152
// #   define PJSIP_MAX_TSX_COUNT          ((640*1024)-1)
// #   define PJSIP_MAX_DIALOG_COUNT       ((640*1024)-1)
// #   define PJSIP_UDP_SO_SNDBUF_SIZE     (24*1024*1024)
// #   define PJSIP_UDP_SO_RCVBUF_SIZE     (24*1024*1024)
#   define PJSIP_SAFE_MODULE            0
#   define PJ_HAS_STRICMP_ALNUM         0
#   define PJSIP_UNESCAPE_IN_PLACE      1
# define PJ_ENABLE_EXTRA_CHECK 0
#endif


