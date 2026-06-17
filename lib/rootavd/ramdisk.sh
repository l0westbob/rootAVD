# shellcheck shell=bash

compression_method() {
    local FILE="$1"
    local FIRSTFILEBYTES
    local METHOD_LZ4="02214c18"
    local METHOD_GZ="1f8b0800"
    local ENDG=""
    FIRSTFILEBYTES=$(xxd -p -c8 -l8 "$FILE")
    FIRSTFILEBYTES="${FIRSTFILEBYTES:0:8}"

    if [ "$FIRSTFILEBYTES" == "$METHOD_LZ4" ]; then
        ENDG=".lz4"
    elif [ "$FIRSTFILEBYTES" == "$METHOD_GZ" ]; then
        ENDG=".gz"
    fi
    echo "$ENDG"
}

detect_ramdisk_compression_method() {
    echo "[*] Detecting ramdisk.img compression"
    RDF=$BASEDIR/ramdisk.img
    CPIO=$BASEDIR/ramdisk.cpio
    CPIOORIG=$BASEDIR/ramdisk.cpio.orig

    local FIRSTFILEBYTES
    local METHOD_LZ4="02214c18"
    local METHOD_GZ="1f8b0800"
    COMPRESS_SIGN=""
    FIRSTFILEBYTES=$(xxd -p -c8 -l8 "$RDF")
    FIRSTFILEBYTES="${FIRSTFILEBYTES:0:8}"
    RAMDISK_LZ4=false
    RAMDISK_GZ=false
    ENDG=""
    METHOD=""

    if [ "$FIRSTFILEBYTES" == "$METHOD_LZ4" ]; then
        ENDG=".lz4"
        METHOD="lz4_legacy"
        RAMDISK_LZ4=true
        mv "$RDF" "$RDF$ENDG"
        RDF=$RDF$ENDG
        COMPRESS_SIGN="$METHOD_LZ4"
    elif [ "$FIRSTFILEBYTES" == "$METHOD_GZ" ]; then
        ENDG=".gz"
        METHOD="gzip"
        RAMDISK_GZ=true
        mv "$RDF" "$RDF$ENDG"
        #cp $RDF $RDF$ENDG
        COMPRESS_SIGN="$METHOD_GZ"
    fi

    if [ "$ENDG" == "" ]; then
        echo "[!] Ramdisk.img uses UNKNOWN compression $FIRSTFILEBYTES"
        abort_script
    fi

    echo "[!] Ramdisk.img uses $METHOD compression"
}

# requires additional setup
construct_environment() {
    ROOT=$(su -c "id -u") 2> /dev/null

    if [[ "$ROOT" == "" ]]; then
        ROOT=$(id -u)
    fi

    echo "[-] Constructing environment - PAY ATTENTION to the AVDs Screen"
    if [[ $ROOT -eq 0 ]]; then
        echo "[!] we are root"
        local BBBIN=$BB
        local COMMONDIR=$BASEDIR/assets
        local NVBASE=/data/adb
        local MAGISKBIN=$NVBASE/magisk

        su -c "rm -rf $MAGISKBIN/* 2>/dev/null && \
				mkdir -p $MAGISKBIN 2>/dev/null && \
				cp -af $BINDIR/. $COMMONDIR/. $BBBIN $MAGISKBIN && \
				chown root.root -R $MAGISKBIN && \
				chmod -R 755 $MAGISKBIN && \
				rm -rf $BASEDIR 2>/dev/null && \
				reboot \
				"
    fi

    echo "[!] not root yet"
    echo "[!] Couldn't construct environment"
    echo "[!] Double Check Root Access"
    echo "[!] Re-Run Script with clean ramdisk.img and try again"
    abort_script
}

repack_ramdisk() {
    echo "[*] Repacking ramdisk .."
    cd "$TMP/ramdisk" > /dev/null || return
    find . | cpio -H newc -o > "$CPIO"
    cd - > /dev/null || return
}

extract_patched_ramdisk() {
    echo "[-] Clearing $TMP/ramdisk"
    rm -fR "$TMP/ramdisk"
    mkdir -p "$TMP/ramdisk"

    cd "$TMP/ramdisk" > /dev/null || return
    "$BASEDIR/busybox" cpio -F "$CPIO" -i '*lib*' > /dev/null 2>&1
    ../../magiskboot cpio ../../ramdisk.cpio "rm -r /lib/modules/*"
    ls -la
    cd - > /dev/null || return
    return 0
}

extract_stock_ramdisk() {
    echo "[-] Clearing $TMP/ramdisk"
    rm -fR "$TMP/ramdisk"
    mkdir -p "$TMP/ramdisk"

    cd "$TMP/ramdisk" > /dev/null || return
    echo "[*] Extracting Stock ramdisk"
    "$BASEDIR/busybox" cpio -F "$CPIO" -i > /dev/null 2>&1
    cd - > /dev/null || return
}

decompress_ramdisk() {
    echo "[-] taken from shakalaca's MagiskOnEmulator/process.sh"
    echo "[*] executing ramdisk splitting / extraction / repacking"
    # extract and check ramdisk
    if [[ $API -ge 30 ]]; then
        "$RAMDISK_GZ" && gzip -fdk "$RDF$ENDG"
        echo "[-] API level greater then 30"
        echo "[*] Check if we need to repack ramdisk before patching .."
        COUNT=$(strings -t d "$RDF" | grep -c 'TRAILER!!')
        if [[ $COUNT -gt 1 ]]; then
            echo "[-] Multiple cpio archives detected"
            REPACKRAMDISK=1
        fi
    fi

    if [ "$DERIVATE" == "BlueStacks" ]; then
        "$RAMDISK_GZ" && gzip -fdk "$RDF$ENDG"
        COUNT=$(strings -t d "$RDF" | grep -c 'TRAILER')
        REPACKRAMDISK=1
    fi

    if [[ -n "$REPACKRAMDISK" ]]; then
        "$RAMDISK_GZ" && rm "$RDF$ENDG"
        echo "[*] Unpacking ramdisk .."
        mkdir -p "$TMP/ramdisk"
        LASTINDEX=0
        IBS=1
        OBS=4096
        OF=$TMP/temp$ENDG

        RAMDISKS=$(strings -t d "$RDF" | grep 'TRAILER' | sed 's|TRAILER.*|TRAILER|')

        for OFFSET in $RAMDISKS; do

            # calculate offset to next archive
            if echo "$OFFSET" | grep -q TRAILER; then
                # find position of end of TRAILER!!! string in image

                if "$RAMDISK_GZ"; then
                    LEN=${#OFFSET}
                    START=$((LASTINDEX + LEN))
                    # find first occurance of string in image, that will be start of cpio archive
                    dd if="$RDF" skip="$START" count="$OBS" ibs="$IBS" obs="$OBS" of="$OF" > /dev/null 2>&1
                    HEAD=$(strings -t d "$OF" | head -1)
                    # vola
                    for i in $HEAD; do
                        HEAD=$i
                        break
                    done
                    LASTINDEX=$((START + HEAD))
                fi
                continue
            fi

            # number of blocks we'll extract
            "$RAMDISK_GZ" && BLOCKS=$(((OFFSET + 128) / IBS))
            if "$RAMDISK_LZ4"; then
                if [ "$LASTINDEX" == "0" ]; then
                    echo "[*] Searching for the real End of the 1st Archive"
                    while [ "$LASTINDEX" == "0" ]; do
                        FIRSTFILEBYTES=$(xxd -p -c8 -l8 -s "$OFFSET" "$RDF")
                        FIRSTFILEBYTES="${FIRSTFILEBYTES:0:8}"
                        if [ "$FIRSTFILEBYTES" == "$COMPRESS_SIGN" ]; then
                            break
                        fi
                        OFFSET=$((OFFSET + 1))
                    done
                fi
                BLOCKS=$((OFFSET / IBS))
            fi

            # extract and dump
            echo "[-] Dumping from $LASTINDEX to $BLOCKS .."
            dd if="$RDF" skip="$LASTINDEX" count="$BLOCKS" ibs="$IBS" obs="$OBS" of="$OF" > /dev/null 2>&1

            cd "$TMP/ramdisk" > /dev/null || return
            "$RAMDISK_GZ" && "$BASEDIR/busybox" cpio -i < "$OF" > /dev/null 2>&1
            if "$RAMDISK_LZ4"; then
                "$BASEDIR/magiskboot" decompress "$OF" "$OF.cpio"
                "$BASEDIR/busybox" cpio -F "$OF.cpio" -i > /dev/null 2>&1
            fi
            cd - > /dev/null || return

            LASTINDEX=$OFFSET
        done
        repack_ramdisk
    else
        echo "[*] After decompressing ramdisk.img, magiskboot will work"
        "$RAMDISK_GZ" && RDF=$RDF$ENDG
        "$BASEDIR/magiskboot" decompress "$RDF" "$CPIO"
    fi
    #update_lib_modules
}

apply_ramdisk_hacks() {

    # Call rootAVD with PATCHFSTAB if you want the RAMDISK merge your modded fstab.ranchu before Magisk Mirror gets mounted

    # cp the read-only fstab.ranchu from vendor partition and add usb:auto for SD devices
    # kernel musst have Mass-Storage + SCSI Support enabled to create /dev/block/sd* nodes

    #echo "[!] PATCHFSTAB=$PATCHFSTAB"
    if ("$PATCHFSTAB"); then
        echo "[-] pulling fstab.ranchu from AVD"
        cp /system/vendor/etc/fstab.ranchu .
        echo "[-] adding usb:auto to fstab.ranchu"
        echo "/devices/*/block/sd* auto auto defaults voldmanaged=usb:auto" >> fstab.ranchu
        #echo "/devices/*/block/loop7 auto auto defaults voldmanaged=sdcard:auto" >> fstab.ranchu
        #echo "/devices/1-* auto auto defaults voldmanaged=usb:auto" >> fstab.ranchu
        "$BASEDIR/magiskboot" cpio ramdisk.cpio \
            "mkdir 0755 overlay.d/vendor" \
            "mkdir 0755 overlay.d/vendor/etc" \
            "add 0644 overlay.d/vendor/etc/fstab.ranchu fstab.ranchu"
        echo "[-] overlay adding complete"
        #echo "[-] jumping back to patching ramdisk for magisk init"
        #else
        #echo "[!] Skipping fstab.ranchu patch with /dev/block/sda"
        #echo "[?] If you want fstab.ranchu patched, Call rootAVD with PATCHFSTAB"
    fi

    #echo "[!] AddRCscripts=$AddRCscripts"
    if ("${AddRCscripts:-false}"); then
        echo "[*] adding *.rc files to ramdisk"
        #for f in *.rc; do
        #	./magiskboot cpio ramdisk.cpio "add 0644 overlay.d/sbin/$f $f"
        #done
        #CSTRC=init.custom.rc
        #touch $CSTRC
        for f in *.rc; do
            #echo "$f" > $CSTRC
            "$BASEDIR/magiskboot" cpio ramdisk.cpio "add 0755 overlay.d/$f $f"
        done

        if [ -d "$BASEDIR/sbin" ]; then
            echo "[*] adding sbin files to ramdisk"
            for f in sbin/*; do
                [ -e "$f" ] || continue
                "$BASEDIR/magiskboot" cpio ramdisk.cpio "add 0755 overlay.d/$f $f"
            done
        fi
        #$BASEDIR/magiskboot cpio ramdisk.cpio "add 0755 overlay.d/$CSTRC $CSTRC"
        echo "[-] overlay adding complete"
        #echo "[-] jumping back to patching ramdisk for magisk init"
        #else
        #echo "[!] Skip adding *.rc scripts into ramdisk.img/sbin/*.rc"
        #echo "[?] If you want *.rc scripts added into ramdisk.img/sbin/*.rc, Call rootAVD with AddRCscripts"
    fi

    #$PATCHFSTAB && SKIPOVERLAYD="#" || SKIPOVERLAYD=""
    update_lib_modules
}

verify_ramdisk_origin() {
    echo "[*] Verifying Boot Image by its Kernel Release number:"
    local KRNAVD=""
    local KRNRDF=""
    KRNAVD=$(uname -r)
    echo "[-] This AVD = $KRNAVD"
    KRNRDF=$(strings "$CPIO" | grep -m 1 vermagic= | sed 's/vermagic=//;s/ .*$//')

    if [ "$KRNRDF" != "" ]; then
        echo "[-]  Ramdisk = $KRNRDF"
        if [ "$KRNAVD" == "$KRNRDF" ]; then
            echo "[!] Ramdisk is probably from this AVD"
        else
            echo "[!] Ramdisk is probably NOT from this AVD"
        fi
    fi
}

test_ramdisk_patch_status() {

    if [ -e ramdisk.cpio ]; then
        "$BASEDIR/magiskboot" cpio ramdisk.cpio test 2> /dev/null
        STATUS=$?
        echo "[-] Checking ramdisk STATUS=$STATUS"
    else
        echo "[-] Stock A only system-as-root"
        STATUS=0
    fi
    PATCHEDBOOTIMAGE=false

    case $((STATUS & 3)) in
        0) # Stock boot
            echo "[-] Stock boot image detected"
            SHA1=$("$BASEDIR/magiskboot" sha1 ramdisk.cpio 2> /dev/null)
            cp -af "$CPIO" "$CPIOORIG" 2> /dev/null
            ;;

        1) # Magisk patched
            echo "[-] Magisk patched boot image detected"
            #construct_environment
            PATCHEDBOOTIMAGE=true
            ;;
        2) # Unsupported
            echo "[!] Boot image patched by unsupported programs"
            echo "[!] Please restore back to stock boot image"
            abort_script
            ;;
    esac

    if [ $((STATUS & 8)) -ne 0 ]; then
        echo "[!] TWOSTAGE INIT image detected - Possibly using 2SI, export env var"
        export TWOSTAGEINIT=true
    fi
    export PATCHEDBOOTIMAGE
}

patching_ramdisk() {
    ##########################################################################################
    # Ramdisk patches
    ##########################################################################################

    echo "[-] Patching ramdisk"

    # Compress to save precious ramdisk space
    if ! "$INITLD"; then
        if "$IS32BITONLY" || ! "$IS64BITONLY"; then
            PREINITDEVICE=$("$BASEDIR/magisk32" --preinit-device)
            "$BASEDIR/magiskboot" compress=xz magisk32 magisk32.xz
        fi

        if "$IS64BITONLY" || ! "$IS32BITONLY"; then
            PREINITDEVICE=$("$BASEDIR/magisk64" --preinit-device)
            "$BASEDIR/magiskboot" compress=xz magisk64 magisk64.xz
        fi
    else
        PREINITDEVICE=$("$BASEDIR/magisk" --preinit-device)
        "$BASEDIR/magiskboot" compress=xz magisk magisk.xz
        "$BASEDIR/magiskboot" compress=xz init-ld init-ld.xz
    fi

    "$INITLD" && SKIPLD="" || SKIPLD="#"

    echo "KEEPVERITY=$KEEPVERITY" > config
    echo "KEEPFORCEENCRYPT=$KEEPFORCEENCRYPT" >> config
    echo "RECOVERYMODE=$RECOVERYMODE" >> config

    if [ -n "$PREINITDEVICE" ]; then
        echo "[*] Pre-init storage partition: $PREINITDEVICE"
        echo "PREINITDEVICE=$PREINITDEVICE" >> config
    fi

    # actually here is the SHA of the bootimage generated
    # we only have one file, so it could make sense
    [ -n "${SHA1:-}" ] && echo "SHA1=$SHA1" >> config

    "$IS64BITONLY" && SKIP32="#" || SKIP32=""
    "$IS64BIT" && SKIP64="" || SKIP64="#"

    "$INITLD" && SKIP32="#"
    "$INITLD" && SKIP64="#"

    if "$STUBAPK"; then
        echo "[!] stub.apk is present, compress and add it to ramdisk"
        "$BASEDIR/magiskboot" compress=xz stub.apk stub.xz
    fi

    "$STUBAPK" && SKIPSTUB="" || SKIPSTUB="#"

    # Here gets the ramdisk.img patched with the magisk su files and stuff

    echo "[*] adding overlay.d/sbin folders to ramdisk"
    "$BASEDIR/magiskboot" cpio ramdisk.cpio \
        "mkdir 0750 overlay.d" \
        "mkdir 0750 overlay.d/sbin"

    apply_ramdisk_hacks

    echo "[!] patching the ramdisk with Magisk Init"
    "$BASEDIR/magiskboot" cpio ramdisk.cpio \
        "add 0750 init magiskinit" \
        "$SKIP32 add 0644 overlay.d/sbin/magisk32.xz magisk32.xz" \
        "$SKIP64 add 0644 overlay.d/sbin/magisk64.xz magisk64.xz" \
        "$SKIPLD add 0644 overlay.d/sbin/magisk.xz magisk.xz" \
        "$SKIPSTUB add 0644 overlay.d/sbin/stub.xz stub.xz" \
        "$SKIPLD add 0644 overlay.d/sbin/init-ld.xz init-ld.xz" \
        "patch" \
        "backup ramdisk.cpio.orig" \
        "mkdir 000 .backup" \
        "add 000 .backup/.magisk config"
}

rename_copy_magisk() {
    if ("$MAGISKVERCHOOSEN"); then
        echo "[!] Copy Magisk.zip to Magisk.apk"
        cp Magisk.zip Magisk.apk
    else
        echo "[!] Rename Magisk.zip to Magisk.apk"
        mv Magisk.zip Magisk.apk
    fi
}

repacking_ramdisk() {
    if [ $((STATUS & 4)) -ne 0 ]; then
        echo "[!] Compressing ramdisk before repacking it"
        "$BASEDIR/magiskboot" cpio ramdisk.cpio compress
    fi

    echo "[*] repacking back to ramdisk.img format"
    # Rename and compress ramdisk.cpio back to ramdiskpatched4AVD.img
    "$BASEDIR/magiskboot" compress="$METHOD" "ramdisk.cpio" "ramdiskpatched4AVD.img"
}
