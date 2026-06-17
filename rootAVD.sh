#!/usr/bin/env bash
##########################################################################################
#
# Magisk Boot Image Patcher - original created by topjohnwu and modded by shakalaca's
# modded by NewBit XDA for Android Studio AVD
##########################################################################################

ROOTAVD_BUNDLED=${ROOTAVD_BUNDLED:-false}
unset CDPATH
if [ -z "${ROOTAVD:-}" ]; then
    ROOTAVD=$(dirname "${BASH_SOURCE:-$0}")
fi
ROOTAVD=$(cd "$ROOTAVD" && pwd) || exit 1
ROOTAVD_LIB_DIR=${ROOTAVD_LIB_DIR:-"$ROOTAVD/lib/rootavd"}

if [ "$ROOTAVD_BUNDLED" != "true" ]; then
    if [ ! -r "$ROOTAVD_LIB_DIR/bootstrap.sh" ]; then
        echo "[!] Missing rootAVD bootstrap module: $ROOTAVD_LIB_DIR/bootstrap.sh" >&2
        echo "[!] Run from a complete checkout or use the generated bundle." >&2
        exit 1
    fi
    # shellcheck disable=SC1091
    . "$ROOTAVD_LIB_DIR/bootstrap.sh"
fi

rootavd_load_modules || exit 1
rootavd_main "$@"
