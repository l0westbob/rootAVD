# shellcheck shell=bash

runMagisk_to_Patch_fake_boot_img() {
    am force-stop "$PKG_NAME"
    echo "[-] Starting Magisk"
    monkey -p "$PKG_NAME" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1
    echo "[*] Install/Patch $FBI and hit Enter when done(max. 60s)"
    read -r -t 60 proceed
    case $proceed in
        *) ;;
    esac
}

detecting_users() {
    local userID=""
    local userZero=0
    echo "[*] Detecting current user"
    userID=$(am get-current-user)
    echo "[-] Current user $userID"
    if [ "$userID" != "$userZero" ]; then
        echo "[-] Switching to user $userZero"
        am switch-user "$userZero"
        userID=$(am get-current-user)
        echo "[-] Current user $userID"
    fi
}

generate_build_prop() {
    echo "[*] generating Build.prop"
    local BPR=$BASEDIR/build.prop
    local recfstab=$BASEDIR/recovery.fstab
    getprop > "$BPR"
    sed -i -e 's/: /=/g' -e 's/\[//g' -e 's/\]//g' "$BPR"

    echo "[*] generating recovery.fstab from fstab.ranchu"
    cp /system/vendor/etc/fstab.ranchu "$recfstab"

    echo "[-] adding Build.prop and recovery.fstab to Stock Ramdisk"
    "$BASEDIR/magiskboot" cpio "$CPIO" \
        "add 0644 system/build.prop build.prop" \
        "add 0644 system/etc/recovery.fstab recovery.fstab"
    #exit
    #BASEDIR=$(pwd)
}

writeLittleEndian() {
    printf '%b' "\\x${1:6:2}\\x${1:4:2}\\x${1:2:2}\\x${1:0:2}"
}

latest_magisk_patched_file() {
    local file=""
    local newest=""
    for file in "$1"/*magisk_patched*; do
        [ -e "$file" ] || continue
        if [ -z "$newest" ] || [ "$file" -nt "$newest" ]; then
            newest=$file
        fi
    done
    printf '%s\n' "$newest"
}

remove_magisk_patched_files() {
    local file=""
    for file in "$1"/*magisk_patched*; do
        [ -e "$file" ] || continue
        rm -f "$file"
    done
}

create_fake_boot_img() {

    if "$DEBUG"; then
        generate_build_prop
    fi

    echo "[*] Creating a fake Boot.img"
    FBHI=$BASEDIR/fakebootheader.img
    FBI=$SDCARD/fakeboot.img
    RAMDISK_SZ="$(printf '%08x' "$(stat -c%s "$CPIO")")"
    PAGESIZE=2048
    PAGESIZE_HEX="$(printf '%08x' "$PAGESIZE")"

    echo "[-] removing old $FBI"
    rm -f "$FBI" "$RDF"

    {
        printf "\x41\x4E\x44\x52\x4F\x49\x44\x21" # ANDROID!
        printf "\x00\x00\x00\x00\x00\x00\x00\x00" # HEADER_VER KERNEL_SZ
        writeLittleEndian "$RAMDISK_SZ"           # RAMDISK_SZ
        printf "\x00\x00\x00\x00"                 # SECOND_SZ
        printf "\x00\x00\x00\x00\x00\x00\x00\x00" # EXTRA_SZ
        printf "\x00\x00\x00\x00"
        writeLittleEndian "$PAGESIZE_HEX" # PAGESIZE_HEX
    } > "$FBHI"

    echo "[!] Only a minimal header is required for Magisk to repack the ramdisk"
    #mv $RDF $CPIO

    echo "[*] repacking ramdisk.img into $FBI"
    "$BASEDIR/magiskboot" repack "$FBHI" "$FBI" > /dev/null 2>&1

    test -f "$FBI"
    RESULT="$?"
    if [[ "$RESULT" != "0" ]]; then
        echo "[*] $FBI could not be created"
        echo "[-] Magisk expects a more complete boot.img header as source"

        # fill 00 (to Pagesize 2048)
        truncate -s "$PAGESIZE" "$FBHI"

        echo "[*] Adding $CPIO to fakeboot.img header"
        cat "$CPIO" >> "$FBHI"

        echo "[*] Checking filesize Padding for Pagesize 2048"

        FBHI_SZ=$(stat -c%s "$FBHI")
        FBHI_PAD_SZ=$((FBHI_SZ / PAGESIZE))
        FBHI_PAD_SZ=$((FBHI_PAD_SZ * PAGESIZE))

        if [[ ! $FBHI_PAD_SZ -eq $FBHI_SZ ]]; then
            echo "[*] Padding filesize to match Pagesize of 2048 Bytes"
            FBHI_PAD_SZ=$((FBHI_SZ / PAGESIZE + 1))
            FBHI_PAD_SZ=$((FBHI_PAD_SZ * PAGESIZE))
            truncate -s "$FBHI_PAD_SZ" "$FBHI"
        fi

        echo "[-] repacking ramdisk.img into $FBI with the more complete header"
        "$BASEDIR/magiskboot" repack "$FBHI" "$FBI" > /dev/null 2>&1

        test -f "$FBI"
        RESULT="$?"
        if [[ "$RESULT" != "0" ]]; then
            echo "[!] $FBI could not be created"
            abort_script
        fi
    fi
    echo "[!] $FBI created"

    InstallMagiskTemporarily
    detecting_users
    runMagisk_to_Patch_fake_boot_img
    RemoveTemporarilyMagisk
}

unpack_patched_ramdisk_from_fake_boot_img() {

    MagiskPatched=$(latest_magisk_patched_file "$SDCARD")
    if [ "$MagiskPatched" != "" ]; then
        echo "[!] magisk_patched file(s) could be found!"
        echo "[*] unpacking latest $MagiskPatched"
        "$BASEDIR/magiskboot" unpack "$MagiskPatched" > /dev/null 2>&1
        echo "[-] deleting all magisk_patched files"
        remove_magisk_patched_files "$SDCARD"
    else
        echo "[!] No magisk_patched file could be found!"
        abort_script
    fi
}

process_fake_boot_img() {

    SDCARD=/sdcard/Download

    echo "[*] Processing fake Boot.img"
    MagiskPatchedFiles=$(latest_magisk_patched_file "$SDCARD")
    if [ "$MagiskPatchedFiles" != "" ]; then
        echo "[!] external magisk_patched file(s) could be found!"
        unpack_patched_ramdisk_from_fake_boot_img
    else
        create_fake_boot_img
        MagiskPatchedFiles=$(latest_magisk_patched_file "$SDCARD")
        unpack_patched_ramdisk_from_fake_boot_img
    fi
}
