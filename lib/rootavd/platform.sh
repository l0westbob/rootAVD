# shellcheck shell=bash

GetAVDPKGRevision() {
    local sourcepropfile="source.properties"
    if [[ -d "$AVDPATH" ]]; then
        cd "$AVDPATH" > /dev/null || return
        # If a source.properties file exist, try to find the Pkg.Revision number
        if ! checkfile "$sourcepropfile"; then
            echo "[-] source.properties file exist"
            echo "[*] AVD system-image $(grep 'Pkg.Revision=' $sourcepropfile)"
        fi
        cd - > /dev/null || return
    fi
}

GetANDROIDHOME() {

    #unset ANDROID_HOME
    #export ANDROID_HOME=~/Downloads/sdk
    #export ANDROID_HOME=~"/Downloads/sd k"
    #export ANDROID_HOME="~/Downloads/sd k"

    local HOME=~
    local ANDROIDHOME_M=$HOME/Library/Android/sdk
    local ANDROIDHOME_L=$HOME/Android/Sdk
    # Keep these as literal help strings so command examples match the legacy output.
    defaultHOME_M="~"/Library/Android/sdk
    defaultHOME_L="~"/Android/Sdk
    defaultHOME=""
    ANDROIDHOME=""
    ENVVAR=""
    local hostarch=""
    SYSIM_DIR=system-images
    ADB_DIR=platform-tools

    NoSystemImages=true

    if [ -d "$ANDROIDHOME_M" ]; then
        ANDROIDHOME=$ANDROIDHOME_M
        ENVVAR=$defaultHOME_M
        defaultHOME=$defaultHOME_M
    elif [ -d "$ANDROIDHOME_L" ]; then
        ANDROIDHOME=$ANDROIDHOME_L
        ENVVAR=$defaultHOME_L
        defaultHOME=$defaultHOME_L
    fi

    if [ -n "${ANDROID_HOME:-}" ]; then
        if [[ "$ANDROID_HOME" == *"~"* ]]; then
            ANDROID_HOME="${ANDROID_HOME/#~/~}"
        fi
        ANDROIDHOME="$ANDROID_HOME"
        ENVVAR="\$ANDROID_HOME"
    fi

    if [[ -d "$ANDROIDHOME/$SYSIM_DIR" ]]; then
        NoSystemImages=false
    fi

    if [[ "$defaultHOME" == "" ]]; then
        hostarch=$(uname -a)
        defaultHOME=$defaultHOME_M
        if [[ "$hostarch" == *"Linux"* ]]; then
            defaultHOME=$defaultHOME_L
        elif [[ "$hostarch" == *"linux"* ]]; then
            defaultHOME=$defaultHOME_M
        fi
    fi

    export NoSystemImages
    export ANDROIDHOME
    export ENVVAR
    export SYSIM_DIR
    export ADB_DIR
    export defaultHOME
    export ANDROIDHOME_M
    export ANDROIDHOME_L
}

FindSystemImages() {
    local SYSIM_EX=""
    local SI=""

    echo "- use ${bold:-}$ENVVAR${normal:-} to search for AVD system images"
    echo "	"

    if $NoSystemImages; then
        echo "[!] No system-images could be found"
        return 1
    fi

    while IFS= read -r SI; do
        [ -n "$SI" ] || continue
        SI=${SI#"$ANDROIDHOME"/}
        if ("${ListAllAVDs:-false}"); then
            if [[ "$SYSIM_EX" == "" ]]; then
                SYSIM_EX+="$SI"
            else
                SYSIM_EX+=" $SI"
            fi
        else
            SYSIM_EX="$SI"
        fi
    done << ROOTAVD_SYSTEM_IMAGES
$(find "$ANDROIDHOME/$SYSIM_DIR" -type f -iname 'ramdisk*.img')
ROOTAVD_SYSTEM_IMAGES

    echo "${bold}Command Examples:${normal}"
    echo "${bold}./rootAVD.sh${normal}"
    echo "${bold}./rootAVD.sh ListAllAVDs${normal}"
    echo "${bold}./rootAVD.sh InstallApps${normal}"
    echo ""

    for SYSIM in $SYSIM_EX; do
        if [[ ! "$SYSIM" == "" ]]; then
            echo "${bold}./rootAVD.sh $SYSIM${normal}"
            echo "${bold}./rootAVD.sh $SYSIM FAKEBOOTIMG${normal}"
            echo "${bold}./rootAVD.sh $SYSIM DEBUG PATCHFSTAB GetUSBHPmodZ${normal}"
            echo "${bold}./rootAVD.sh $SYSIM restore${normal}"
            echo "${bold}./rootAVD.sh $SYSIM InstallKernelModules${normal}"
            echo "${bold}./rootAVD.sh $SYSIM InstallPrebuiltKernelModules${normal}"
            echo "${bold}./rootAVD.sh $SYSIM InstallPrebuiltKernelModules GetUSBHPmodZ PATCHFSTAB DEBUG${normal}"
            echo "${bold}./rootAVD.sh $SYSIM AddRCscripts${normal}"
            echo ""
        else
            echo ""
            echo "No ramdisk files could be found"
            echo ""
        fi
    done
}
