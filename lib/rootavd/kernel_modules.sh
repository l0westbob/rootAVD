# shellcheck shell=bash

strip_html_links() {
    sed -i -e 's/<a href=/\n<a href=/g;s/<\/a>/<\/a>\n/g' "$1"
}
strip_kernel_builds() {
    sed -i -n '/>Update kernel to builds/p' "$1"
}
strip_next_pages() {
    sed -n '/>Next/p' "$1"
}

kernel_build_label() {
    local label="$1"
    while [ "$label" != "${label#*<}" ]; do
        label=${label%%<*}${label#*>}
    done
    echo "$label"
}

kernel_commit_archive_name() {
    local line="$1"
    local commit_id=""
    commit_id=${line#*\"}
    commit_id=${commit_id%%\"*}
    echo "${commit_id##*/}.tar.gz"
}

kernel_first_module_file() {
    find "$1" -name '*.ko' -type f -print -quit 2> /dev/null
}

kernel_module_vermagic() {
    local module_file="$1"
    [ -n "$module_file" ] || return 0
    strings "$module_file" | grep vermagic= | sed 's/vermagic=//;s/ .*$//' 2> /dev/null
}

kernel_module_android_build() {
    local module_file="$1"
    [ -n "$module_file" ] || return 0
    strings "$module_file" | grep 'Android (' | sed 's/ c.*$//' 2> /dev/null
}

find_next_pages() {
    local URL="$2"
    local NEXTPAGESRC=""
    local TMPHTML="tmp.html"
    rm -rf "$TMPHTML"
    NEXTPAGESRC=$(strip_next_pages "$1")

    echo "[-] Find Next Page(s)"
    while [[ "$NEXTPAGESRC" != "" ]]; do
        NEXTPAGESRC=$(echo "$NEXTPAGESRC" | sed -e 's/.*href="//' -e 's/">Next.*//')
        #echo $NEXTPAGESRC
        DownLoadFile "$URL" "$NEXTPAGESRC" "$TMPHTML"
        strip_html_links "$TMPHTML"
        cat "$TMPHTML" >> "$1"
        NEXTPAGESRC=$(strip_next_pages "$TMPHTML")
    done
}

update_lib_modules() {
    local INITRAMFS=initramfs.img
    if ("${AVDIsOnline:-false}"); then
        if ("${InstallPrebuiltKernelModules:-false}"); then
            local KERNEL_ARCH="x86-64"
            if [[ $ABI == *"arm"* ]]; then
                KERNEL_ARCH="arm64"
            fi
            local unameR=""
            unameR=$(uname -r)
            local majmin=${unameR%.*}
            #majmin=5.15
            local installedbuild=${unameR##*ab}

            echo "[*] Fetching Kernel Data:"
            echo "[-]              Android: $AVERSION"
            echo "[-]                 Arch: $KERNEL_ARCH"
            echo "[-]                Uname: $unameR"
            echo "[-]              Version: $majmin"
            echo "[-]        Build Version: $installedbuild"

            local URL="https://android.googlesource.com"
            #local TAG="android$AVERSION-mainline-sdkext-release"
            local TAG="android$AVERSION-gsi"
            #local TAG="master"
            local KERSRC="/kernel/prebuilts/$majmin/$KERNEL_ARCH/+log/refs/heads/$TAG"
            #local KERSRC="/platform/prebuilts/qemu-kernel/+log/refs/heads/$TAG"
            #https://android.googlesource.com/platform/prebuilts/qemu-kernel/+log/refs/heads/android11-gsi
            #https://android.googlesource.com/platform/prebuilts/qemu-kernel/+/refs/heads/android11-gsi
            #local KERSRC="/kernel/prebuilts/$majmin/$KERNEL_ARCH/+log/refs/heads/android$AVERSION-mainline-sdkext-release"

            local MODSRC="/kernel/prebuilts/common-modules/virtual-device/$majmin/$KERNEL_ARCH/+log/refs/heads/$TAG"
            #local MODSRC="/kernel/prebuilts/common-modules/virtual-device/$majmin/$KERNEL_ARCH/+log/refs/heads/android$AVERSION-mainline-sdkext-release"
            local KERPREMASHTML="kernelprebuiltsmaster.html"
            local KERDST="prebuiltkernel.tar.gz"
            local MODDST="prebuiltmodules.tar.gz"
            local MODPREMASHTML="moduleprebuiltsmaster.html"
            local TMPSTRIPFILE="tmpstripfile"
            local TMPREADFILE="tmpreadfile"
            local FILETOREAD=""
            local FILETOSTRIP=""

            local BUILDVERCHOOSEN=""
            local CHOOSENLINE=""
            local KERCOMMITID=""
            local MODCOMMITID=""
            local OLDMODULE=""
            local NEWMODULE=""

            local ker_line_cnt=""
            local mod_line_cnt=""
            local i=""

            DownLoadFile "$URL" "$KERSRC" "$KERPREMASHTML"
            strip_html_links "$KERPREMASHTML"
            find_next_pages "$KERPREMASHTML" "$URL"
            strip_kernel_builds "$KERPREMASHTML"

            DownLoadFile "$URL" "$MODSRC" "$MODPREMASHTML"
            strip_html_links "$MODPREMASHTML"
            find_next_pages "$MODPREMASHTML" "$URL"
            strip_kernel_builds "$MODPREMASHTML"

            ker_line_cnt=$(sed -n '$=' "$KERPREMASHTML")
            mod_line_cnt=$(sed -n '$=' "$MODPREMASHTML")

            if [ "$ker_line_cnt" -gt "$mod_line_cnt" ]; then
                FILETOREAD="$KERPREMASHTML"
                FILETOSTRIP="$MODPREMASHTML"
            else
                FILETOREAD="$MODPREMASHTML"
                FILETOSTRIP="$KERPREMASHTML"
            fi

            touch "$TMPSTRIPFILE"
            touch "$TMPREADFILE"

            echo "[*] Find common Build Versions"
            while IFS= read -r line; do
                BUILDVER=$(kernel_build_label "$line")
                if grep -F -e ">$BUILDVER<" "$FILETOSTRIP" >> "$TMPSTRIPFILE"; then
                    echo "$line" >> "$TMPREADFILE"
                fi
            done < "$FILETOREAD"

            mv -f "$TMPREADFILE" "$FILETOREAD"
            mv -f "$TMPSTRIPFILE" "$FILETOSTRIP"

            while :; do
                i=0
                echo "[!] Installed Kernel builds $installedbuild"
                echo "[?] Choose a Prebuild Kernel/Module Version"
                while IFS= read -r line; do
                    i=$((i + 1))
                    BUILDVER=$(kernel_build_label "$line")
                    echo "[$i] $BUILDVER"
                done < "$KERPREMASHTML"

                read -r choice
                case $choice in
                    *)
                        if [[ "$choice" == "" ]]; then
                            choice=1
                        fi
                        if [ "$choice" -le "$i" ]; then
                            BUILDVERCHOOSEN=$choice
                            CHOOSENLINE=$(sed -n "${BUILDVERCHOOSEN}p" "$KERPREMASHTML")
                            BUILDVER=$(kernel_build_label "$CHOOSENLINE")
                            KERCOMMITID=$(kernel_commit_archive_name "$CHOOSENLINE")

                            CHOOSENLINE=$(sed -n "${BUILDVERCHOOSEN}p" "$MODPREMASHTML")
                            MODCOMMITID=$(kernel_commit_archive_name "$CHOOSENLINE")

                            echo "[$BUILDVERCHOOSEN] You choose: $BUILDVER"
                            break
                        fi
                        echo "Choice is out of range"
                        ;;
                esac
            done

            echo "[-] Downloading Kernel and its Modules..."
            # Download Kernel
            DownLoadFile "$URL/kernel/prebuilts/$majmin/$KERNEL_ARCH/+archive/" "$KERCOMMITID" "$KERDST"
            # Download Modules
            DownLoadFile "$URL/kernel/prebuilts/common-modules/virtual-device/$majmin/$KERNEL_ARCH/+archive/" "$MODCOMMITID" "$MODDST"

            echo "[*] Extracting kernel-$majmin to bzImage"
            tar -xf "$KERDST" "kernel-$majmin" -O > bzImage
            echo "[-] Extracting $INITRAMFS"
            tar -xf "$MODDST" "$INITRAMFS"

            InstallKernelModules=true
        fi
    fi

    if ("${InstallKernelModules:-false}"); then

        if [ -e "$INITRAMFS" ]; then
            echo "[!] Installing new Kernel Modules"
            echo "[*] Copy initramfs.img $TMP/initramfs"
            mkdir -p "$TMP/initramfs"
            CMPRMTH=$(compression_method "$INITRAMFS")
            cp "$INITRAMFS" "$TMP/initramfs/initramfs.cpio$CMPRMTH"
        else
            return 0
        fi

        echo "[-] Extracting Modules from $INITRAMFS"

        cd "$TMP/initramfs" > /dev/null || return
        "$BASEDIR/magiskboot" decompress "initramfs.cpio$CMPRMTH"
        "$BASEDIR/busybox" cpio -F initramfs.cpio -i '*lib*' > /dev/null 2>&1
        cd - > /dev/null || return

        if [ ! -d "$TMP/initramfs/lib/modules" ]; then
            echo "[!] $INITRAMFS has no lib/modules, aborting"
            rm -rf bzImage 2> /dev/null
            return 0
        fi

        # If Stock or patched Status
        if "$PATCHEDBOOTIMAGE"; then
            # If it is a already patched ramdisk
            if [ ! -e "$TMP/ramdisk" ]; then
                mkdir -p "$TMP/ramdisk"
            fi

            echo "[*] Extracting Modules from patched ramdisk.img"
            cd "$TMP/ramdisk" > /dev/null || return
            "$BASEDIR/busybox" cpio -F "$CPIO" -i '*lib*' > /dev/null 2>&1
            cd - > /dev/null || return
        else
            # If it is a Stock Ramdisk
            echo "[*] Extracting Modules from Stock ramdisk.img"
            extract_stock_ramdisk
        fi

        OLDMODULE=$(kernel_first_module_file "$TMP/ramdisk/.")
        OLDVERMAGIC=$(kernel_module_vermagic "$OLDMODULE")
        OLDANDROID=$(kernel_module_android_build "$OLDMODULE")

        # If Stock or patched Status
        if "$PATCHEDBOOTIMAGE"; then
            # If it is a already patched ramdisk
            echo "[*] Removing Modules from patched ramdisk.img"
            "$BASEDIR/magiskboot" cpio "$CPIO" "rm -r lib" > /dev/null 2>&1
        else
            # If it is a Stock Ramdisk
            echo "[*] Removing Modules from Stock ramdisk.img"
            rm -f "$TMP"/ramdisk/lib/modules/*
        fi

        echo "[!] $OLDVERMAGIC"
        echo "[!] $OLDANDROID"

        echo "[-] Installing new Modules into ramdisk.img"
        cd "$TMP/initramfs" > /dev/null || return
        find ./lib/modules -type f -name '*' -exec cp {} . \;
        find . -name '*.ko' -exec cp {} "$TMP/ramdisk/lib/modules/" \;
        NEWMODULE=$(kernel_first_module_file ".")
        NEWVERMAGIC=$(kernel_module_vermagic "$NEWMODULE")
        NEWANDROID=$(kernel_module_android_build "$NEWMODULE")
        cp modules.alias modules.dep modules.load modules.softdep "$TMP/ramdisk/lib/modules/"
        cd - > /dev/null || return

        echo "[!] $NEWVERMAGIC"
        echo "[!] $NEWANDROID"

        echo "[*] Adjusting modules.load and modules.dep"
        cd "$TMP/ramdisk/lib/modules" > /dev/null || return
        sed -i -E 's~[^[:blank:]]+/~/lib/modules/~g' modules.load
        sort -s -o modules.load modules.load
        sed -i -E 's~[^[:blank:]]+/~/lib/modules/~g' modules.dep
        sort -s -o modules.dep modules.dep
        cd - > /dev/null || return

        # If Stock or patched Status
        if "$PATCHEDBOOTIMAGE"; then
            # If it is a already patched ramdisk
            echo "[*] Adding new Modules into patched ramdisk.img"
            cd "$TMP/ramdisk/lib/modules" > /dev/null || return
            "$BASEDIR/magiskboot" cpio "$CPIO" \
                "mkdir 0755 lib" \
                "mkdir 0755 lib/modules" > /dev/null 2>&1
            for f in *.*; do
                [ -e "$f" ] || continue
                "$BASEDIR/magiskboot" cpio "$CPIO" \
                    "add 0644 lib/modules/$f $f" > /dev/null 2>&1
                #echo "$f"
            done
            cd - > /dev/null || return
        else
            # If it is a Stock Ramdisk
            repack_ramdisk
        fi
    fi
}
