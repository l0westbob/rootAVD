# shellcheck shell=bash

MakeBlueStacksRW() {

    if checkfile "$BLUESTACKSPATH/$AVBOXFILE"; then
        echo "[!] $AVBOXFILE not found"
        echo "[!] check your BlueStacks installation"
        return 1
    fi
    echo "[!] $AVBOXFILE found"
    create_backup "$AVBOX"
    echo "[*] Changing $ROOTVDIFILE type to \"Normal\""
    sed 's,location="Root.vdi" format="VDI" type="Readonly",location="Root.vdi" format="VDI" type="Normal",' "$AVBOX" > "$AVBOX.edit"
    mv "$AVBOX.edit" "$AVBOX"
}

CheckBlueStacksSUBinary() {
    SU="/system/xbin/bstk/su"
    echo "[-] Checking for build-in $SU binary"
    if [ ! -e "$SU" ]; then
        echo "[!] We need Root to get Root"
        echo "[!] No $SU could be found"
        abort_script
    fi
    echo "[*] $SU binary found"

    # Disable SELinux
    #$SU -c 'setenforce 0'
}

GetBlueStacksRamdisk() {
    echo "[*] Getting BlueStacks Ramdisk"

    BA="/boot/android"

    BSTKRDF="$BA/android/ramdisk.img"
    BSTKRDFBU="$BSTKRDF.backup"

    echo "[-] remounting $BA as RW"
    mount -o remount,rw "$BA"

    if [ ! -e "$BSTKRDFBU" ]; then
        echo "[*] Copy $BSTKRDF to $BSTKRDFBU"
        cp -fac "$BSTKRDF" "$BSTKRDFBU"
    fi

    echo "[*] Copy $BSTKRDF to $BASEDIR"
    cp -fac "$BSTKRDF" "$BASEDIR/"
}

FinalizeBlueStacks() {
    if ! "$DEBUG"; then
        echo "[-] Overwriting $BSTKRDF with ramdiskpatched4AVD.img"
        cp -f ramdiskpatched4AVD.img "$BSTKRDF"
        echo "[-] Change ramdisk Mode to 644"
        chmod 644 "$BSTKRDF"
        echo "[-] Change ramdisk Owner to System"
        chown 1000:1000 "$BSTKRDF"
    fi

    echo "[*] Change $BASEDIR Owner back to Shell while root for deleting reasons"
    chown 2000:2000 "$BASEDIR" -R
    echo "[*] Cleaning /data/adb Folder"
    rm -rf /data/adb
    echo "[-] remounting $BA as RO"
    mount -o remount,ro "$BA"
}

# Taken from the Magisk Modules Template by topjohnwu
# set_perm <target> <owner> <group> <permission> [context]
#     if [context] is empty, it will default to "u:object_r:system_file:s0"
#     this function is a shorthand for the following commands
#       chown owner.group target
#       chmod permission target
#       chcon context target

set_perm() {
    chown "$2:$3" "$1" || return 1
    chmod "$4" "$1" || return 1
    CON=${5:-}
    [ -z "$CON" ] && CON=u:object_r:system_file:s0
    chcon "$CON" "$1" || return 1
}

# set_perm_recursive <directory> <owner> <group> <dirpermission> <filepermission> [context]
#     if [context] is empty, it will default to "u:object_r:system_file:s0"
#     for all files in <directory>, it will call:
#       set_perm file owner group filepermission context
#     for all directories in <directory> (including itself), it will call:
#       set_perm dir owner group dirpermission context

set_perm_recursive() {
    find "$1" -type d 2> /dev/null | while IFS= read -r dir; do
        set_perm "$dir" "$2" "$3" "$4" "${6:-}"
    done
    find "$1" \( -type f -o -type l \) 2> /dev/null | while IFS= read -r file; do
        set_perm "$file" "$2" "$3" "$5" "${6:-}"
    done
}

SettingBlueStackMagiskPermissions() {
    echo "[*] Setting BlueStack Magisk Permissions"
    local ROOT=""
    ROOT=$(stat -c %u /dev)
    cd "$BLSTKMAGISKDIR"/ > /dev/null || return
    set_perm_recursive assets "$ROOT" "$ROOT" 0750 0777
    set_perm ./busybox "$ROOT" "$ROOT" 0750 u:object_r:magisk_file:s0

    if [ -e "magisk64" ]; then
        set_perm ./magisk64 "$ROOT" "$ROOT" 0750 u:object_r:magisk_exec:s0
    elif [ -e "magisk32" ]; then
        set_perm ./magisk32 "$ROOT" "$ROOT" 0750 u:object_r:magisk_exec:s0
    fi

    set_perm ./magiskboot "$ROOT" "$ROOT" 0750
    set_perm ./magiskinit "$ROOT" "$ROOT" 0750
    set_perm ./overlay.sh "$ROOT" "$ROOT" 0750
    set_perm ../init.rc "$ROOT" "$ROOT" 0750
    cd - > /dev/null || return
}

InstallMagiskIntoBlueStacksRamdisk() {
    echo "[-] Patching BlueStacks ramdisk .."
    echo "[*] Taken from HuskyDG script MagiskOnEmu/libbash.so"

    MAGISKBASE="/magisk"
    BLSTKMAGISKDIR=$TMP/ramdisk$MAGISKBASE
    local INITRC=$TMP/ramdisk/init.rc
    rm -rf "$BLSTKMAGISKDIR" 2> /dev/null
    mkdir -p "$BLSTKMAGISKDIR"
    echo "[-] copying Magisk Assets and Files"
    cp -Rf "$BASEDIR/assets" "$BLSTKMAGISKDIR/"
    cp "$BB" "$BLSTKMAGISKDIR/"
    cp "$BASEDIR/magisk32" "$BLSTKMAGISKDIR/"
    cp "$BASEDIR/magisk64" "$BLSTKMAGISKDIR/"
    cp "$BASEDIR/magiskboot" "$BLSTKMAGISKDIR/"
    cp "$BASEDIR/magiskinit" "$BLSTKMAGISKDIR/"
    cp "$INITRC" "$BLSTKMAGISKDIR/"
    echo "[*] generating Magisk Boot Scripts"
    magisk_loader
    echo "[*] Magisk files will be mounted to $MAGISKTMP"
    echo "[-] writing overlay.sh Script"
    echo "${overlay_loader:?}" > "$BLSTKMAGISKDIR/overlay.sh"
    echo "[*] appending boot commands to init.rc"
    echo "${magiskloader:?}" >> "$TMP/ramdisk/init.rc"

    # setting permissions
    SettingBlueStackMagiskPermissions

    echo "[-] Repacking BlueStacks ramdisk .."
    cd "$TMP/ramdisk" > /dev/null || return
    find . | cpio -H newc -o > "$CPIO"
    cd - > /dev/null || return
}
