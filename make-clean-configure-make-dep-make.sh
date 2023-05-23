#!/bin/bash

make clean

CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure \
    --disable-pjsua2 --disable-upnp \
    --disable-speex-aec --disable-l16-codec --disable-gsm-codec --disable-g722-codec \
    --disable-g7221-codec --disable-speex-codec --disable-ilbc-codec --disable-ffmpeg --disable-v4l2 --disable-vpx \
    --disable-android-mediacodec --disable-opencore-amr --disable-silk --disable-bcg729 --disable-libwebrtc \
    --enable-epoll --enable-kqueue \
    --prefix="$1"

make dep

make

