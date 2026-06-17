# shellcheck shell=bash

json_value() {
    "$BB" grep -o "\"""${1}""\"\:.*" | "$BB" sed -e "s/.*\"""${1}""\": //" -e 's/[",}]*$//' -e 's/["]*$//' -e 's/[,]*$//' -e "s/\"//" -n -e "${2}"p
}

CheckAVDIsOnline() {
    if [ -z "${AVDIsOnline:-}" ]; then
        echo "[-] Checking AVDs Internet connection..."
        AVDIsOnline=false
        if "$BB" timeout 3 "$BB" wget -q --spider --no-check-certificate http://github.com > /dev/null 2>&1; then
            AVDIsOnline=true
        else
            echo "[-] Checking AVDs Internet connection another way..."
            if printf 'GET http://google.com HTTP/1.0\n\n' | "$BB" timeout 3 "$BB" nc -v google.com 80 > /dev/null 2>&1; then
                AVDIsOnline=true
            fi
        fi
        $AVDIsOnline && echo "[!] AVD is online" || echo "[!] AVD is offline"
    fi
    export AVDIsOnline
}

GetPrettyVer() {
    if echo "$1" | "$BB" grep -q '\.'; then
        PRETTY_VER=$1
    else
        PRETTY_VER="$1($2)"
    fi
    echo "$PRETTY_VER"
}

DownLoadFile() {
    CheckAVDIsOnline
    if ("$AVDIsOnline"); then
        local URL="$1"
        local SRC="$2"
        local DST="$3"

        OF=$BASEDIR/download.tmp
        rm -f "$OF"
        BS=1024
        CUTOFF=100
        COUNT=0

        if [ "$DST" == "" ]; then
            DST=$BASEDIR/$SRC
        else
            DST=$BASEDIR/$DST
        fi
        #echo "[*] Downloading File $SRC"
        "$BB" wget -q -O "$DST" --no-check-certificate "$URL$SRC"
        RESULT="$?"
        while [ "$RESULT" != "0" ]; do
            echo "[!] Error while downloading File $SRC"
            echo "[-] patching it together"
            FSIZE=$(./busybox stat "$DST" -c %s)
            if [ "$FSIZE" -gt "$BS" ]; then
                COUNT=$((FSIZE / BS))
                if [ "$COUNT" -gt "$CUTOFF" ]; then
                    COUNT=$((COUNT - CUTOFF))
                fi
            fi
            "$BB" dd if="$DST" count="$COUNT" bs="$BS" of="$OF" > /dev/null 2>&1
            mv -f "$OF" "$DST"
            "$BB" wget -q -O "$DST" --no-check-certificate "$URL$SRC" -c
            RESULT="$?"
        done
        echo "[!] Downloading File $SRC complete!"
    fi
}

GetUSBHPmod() {
    USBHPZSDDL="/sdcard/Download"
    USBHPZ="https://gitlab.com/newbit/usbhostpermissions/-/releases/permalink/latest/downloads/usbhostpermissions"

    set -- "$USBHPZSDDL"/usbhostpermissions*.zip
    if [ -e "$1" ]; then
        echo "[*] USB HOST Permissions Module Zip is already present"
    else
        echo "[*] Downloading USB HOST Permissions Module Zip"
        "$BB" wget --no-check-certificate "$USBHPZ" -S -o response.txt
        USBHPZ=$("$BB" grep -Eo 'https://[^"]+\.(zip)' response.txt)
        "$BB" wget -q -P "$USBHPZSDDL" --no-check-certificate "$USBHPZ"
    fi
}

FetchMagiskDLData() {
    local SRCURL="$1"
    local CHANNEL="$2"
    local JSON="$CHANNEL.json"
    local VER=""
    local VER_CODE=""
    local DLL=""
    local i=1

    rm -rf ./*.json > /dev/null 2>&1
    "$BB" wget -q --no-check-certificate "$SRCURL$JSON"
    VER=$(json_value "version" < "$JSON")
    VER_CODE=$(json_value "versionCode" 1 < "$JSON")
    DLL=$(json_value "link" 1 < "$JSON")
    VER=$(GetPrettyVer "$VER" "$VER_CODE")

    if ! echo "$DLL" | "$BB" grep -q 'https'; then
        DLL=$SRCURL$DLL
    fi

    if [ -e "$MAGISK_DL_LINKS" ]; then
        echo "$DLL" >> "$MAGISK_DL_LINKS"
        echo "$VER" >> "$MAGISK_VERSIONS"
        echo "$CHANNEL" >> "$MAGISK_CHANNEL"
        i=$("$BB" sed -n '$=' "$MAGISK_DL_LINKS")
        echo "[$i] $CHANNEL $VER" >> "$MAGISK_MENU"
    else
        if [[ "$MAGISK_LOCL_VER" != "" ]]; then
            echo "local" > "$MAGISK_DL_LINKS"
            echo "$MAGISK_LOCL_VER" > "$MAGISK_VERSIONS"
            echo "local $CHANNEL" > "$MAGISK_CHANNEL"
            echo "[$i] local $CHANNEL $MAGISK_LOCL_VER (ENTER)" > "$MAGISK_MENU"
            i=$((i + 1))
        fi
        echo "$DLL" >> "$MAGISK_DL_LINKS"
        echo "$VER" >> "$MAGISK_VERSIONS"
        echo "$CHANNEL" >> "$MAGISK_CHANNEL"
        if [[ "$i" == "1" ]]; then

            echo "[$i] $CHANNEL $VER (ENTER)" >> "$MAGISK_MENU"
        else
            #echo $CHANNEL > $MAGISK_CHANNEL
            echo "[$i] $CHANNEL $VER" >> "$MAGISK_MENU"
        fi
    fi
    rm -rf ./*.json > /dev/null 2>&1
}

FetchMagiskRLCommits() {
    #$GITHUB $TJWCOMMITSURL $TJWBLOBURL $CHANNEL $TJWREPOURL
    local DOMAIN="$1"
    local COMMITSURL="$2"
    local BLOBURL="$3"
    local CHANNEL="$4"
    local JSON="$CHANNEL.json"
    local REPOURL="$5"
    local COMMITS=""

    rm -rf "$JSON"
    "$BB" wget -q --no-check-certificate "$DOMAIN$COMMITSURL$JSON"

    COMMITS=$("$BB" grep "$BLOBURL" "$JSON" | "$BB" sed -e 's,.*'"$BLOBURL"',,' -e 's,'"$JSON"'.*,,')

    for commit in $COMMITS; do
        FetchMagiskDLData "$RAWGITHUB$REPOURL$commit" "$CHANNEL"
    done
}

CheckAvailableMagisks() {

    MAGISK_VERSIONS=$BASEDIR/magisk_versions.txt
    MAGISK_DL_LINKS=$BASEDIR/magisk_dl_links.txt
    MAGISK_MENU=$BASEDIR/magisk_menu.txt
    MAGISK_CHANNEL=$BASEDIR/magisk_channel.txt

    local GITHUB="https://github.com/"
    RAWGITHUB="https://raw.githubusercontent.com/"
    local TJWREPOURL="topjohnwu/magisk-files/"
    local TJWCOMMITSURL="topjohnwu/magisk-files/commits/master/"
    local TJWBLOBURL="topjohnwu/magisk-files/blob/"

    #local VVB2060REPOURL="vvb2060/magisk_files/"
    #local VVB2060COMMITSURL="vvb2060/magisk_files/commits/alpha/"
    #local VVB2060BLOBURL="vvb2060/magisk_files/blob/"
    local DLL_cnt=0

    if [ -z "${MAGISKVERCHOOSEN:-}" ]; then

        UFSH=$BASEDIR/assets/util_functions.sh
        OF=$BASEDIR/download.tmp
        BS=1024
        CUTOFF=100

        if [ -e "$UFSH" ]; then
            MAGISK_LOCL_VER=$("$BB" grep "$UFSH" -e "MAGISK_VER" -w | sed 's/^.*=//')
            MAGISK_LOCL_VER_CODE=$("$BB" grep "$UFSH" -e "MAGISK_VER_CODE" -w | sed 's/^.*=//')
            MAGISK_LOCL_VER=$(GetPrettyVer "$MAGISK_LOCL_VER" "$MAGISK_LOCL_VER_CODE")
        else
            MAGISK_LOCL_VER=""
            MAGISK_LOCL_VER_CODE=""
        fi

        CheckAVDIsOnline
        if "$AVDIsOnline"; then
            echo "[!] Checking available Magisk Versions"

            rm ./*.txt > /dev/null 2>&1

            FetchMagiskDLData "$RAWGITHUB${TJWREPOURL}master/" "stable"
            FetchMagiskDLData "$RAWGITHUB${TJWREPOURL}master/" "canary"
            #FetchMagiskDLData $RAWGITHUB$VVB2060REPOURL"alpha/" "alpha"

            while :; do
                DLL_cnt=$("$BB" sed -n '$=' "$MAGISK_DL_LINKS")
                echo "[?] Choose a Magisk Version to install and make it local"
                echo "[s] (s)how all available Magisk Versions"
                cat "$MAGISK_MENU"
                read -r -t 10 choice
                case $choice in
                    *)
                        if [[ "$choice" == "" ]]; then
                            choice=1
                        fi

                        if [[ "$choice" -gt 0 && "$choice" -le "$DLL_cnt" ]]; then
                            MAGISK_VER=$("$BB" sed "${choice}!d" "$MAGISK_VERSIONS")
                            MAGISK_CNL=$("$BB" sed "${choice}!d" "$MAGISK_CHANNEL")
                            echo "[-] You choose Magisk $MAGISK_CNL Version $MAGISK_VER"

                            MAGISK_DL=$("$BB" sed "${choice}!d" "$MAGISK_DL_LINKS")
                            if [[ "$MAGISK_DL" == "local" ]]; then
                                MAGISKVERCHOOSEN=false
                            fi
                            break
                        fi

                        if [[ "$choice" == "s" ]]; then
                            echo "[!] Fetching all available Magisk Versions..."
                            rm ./*.txt > /dev/null 2>&1
                            FetchMagiskRLCommits "$GITHUB" "$TJWCOMMITSURL" "$TJWBLOBURL" "stable" "$TJWREPOURL"
                            FetchMagiskRLCommits "$GITHUB" "$TJWCOMMITSURL" "$TJWBLOBURL" "canary" "$TJWREPOURL"
                            #FetchMagiskRLCommits $GITHUB $VVB2060COMMITSURL $VVB2060BLOBURL "alpha" $VVB2060REPOURL
                        else
                            echo "invalid option $choice"
                        fi
                        ;;
                esac
            done
            #exit
        else
            MAGISK_VER=$MAGISK_LOCL_VER
            MAGISKVERCHOOSEN=false
        fi

        if [ -z "${MAGISKVERCHOOSEN:-}" ]; then
            echo "[*] Deleting local Magisk $MAGISK_LOCL_VER"
            rm -rf "$MZ"
            rm -rf ./*.apk
            echo "[*] Downloading Magisk $MAGISK_CNL $MAGISK_VER"
            "$BB" wget -q -O "$MZ" --no-check-certificate "$MAGISK_DL"
            RESULT="$?"
            while [ "$RESULT" != "0" ]; do
                echo "[!] Error while downloading Magisk $MAGISK_CNL $MAGISK_VER"
                echo "[-] patching it together"
                FSIZE=$(./busybox stat "$MZ" -c %s)
                if [ "$FSIZE" -gt "$BS" ]; then
                    COUNT=$((FSIZE / BS))
                    if [ "$COUNT" -gt "$CUTOFF" ]; then
                        COUNT=$((COUNT - CUTOFF))
                    fi
                fi
                "$BB" dd if="$MZ" count="$COUNT" bs="$BS" of="$OF" > /dev/null 2>&1
                mv -f "$OF" "$MZ"
                "$BB" wget -q -O "$MZ" --no-check-certificate "$MAGISK_DL" -c
                RESULT="$?"
            done
            echo "[!] Downloading Magisk $MAGISK_CNL $MAGISK_VER complete!"
            MAGISKVERCHOOSEN=true
            PrepBusyBoxAndMagisk
        fi

        # Call rootAVD with GetUSBHPmodZ to download the usbhostpermissions module.
        "${GetUSBHPmodZ:-false}" && "$AVDIsOnline" && GetUSBHPmod
    fi
    export MAGISK_VER
    export MAGISKVERCHOOSEN
    export UFSH
}
