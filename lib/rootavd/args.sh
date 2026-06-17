# shellcheck shell=bash

rootavd_reset_args() {
    DEBUG=false
    PATCHFSTAB=false
    GetUSBHPmodZ=false
    RAMDISKIMG=false
    restore=false
    InstallKernelModules=false
    InstallPrebuiltKernelModules=false
    ListAllAVDs=false
    InstallApps=false
    UpdateBusyBoxScript=false
    AddRCscripts=false
    BLUESTACKS=false
    toggleRamdisk=false
    FAKEBOOTIMG=false
}

ProcessArguments() {
    rootavd_reset_args

    # Call rootAVD with SOURCING if you just want to source it
    # or export SOURCING=true if you are in crosh
    if [ -z "${SOURCING:-}" ]; then
        SOURCING=false
    fi
    if has_argument "SOURCING" "$@"; then
        SOURCING=true
    fi

    # While debugging and developing you can turn this flag on
    if has_argument "DEBUG" "$@"; then
        DEBUG=true
        # Shows whatever line get executed...
        #set -x
    fi

    # Call rootAVD with PATCHFSTAB if you want the RAMDISK merge your modded fstab.ranchu before Magisk Mirror gets mounted
    if has_argument "PATCHFSTAB" "$@"; then
        PATCHFSTAB=true
    fi

    # Call rootAVD with GetUSBHPmodZ to download the usbhostpermissions module
    if has_argument "GetUSBHPmodZ" "$@"; then
        GetUSBHPmodZ=true
    fi

    # Call rootAVD with ListAllAVDs to show all AVDs with command examples
    if has_argument "ListAllAVDs" "$@"; then
        ListAllAVDs=true
    fi

    # Call rootAVD with InstallApps to just install all APKs placed in the Apps folder
    if has_argument "InstallApps" "$@"; then
        InstallApps=true
    fi

    # Call rootAVD with UpdateBusyBoxScript to update the Busybox Version within the rootAVD.sh
    if has_argument "UpdateBusyBoxScript" "$@"; then
        UpdateBusyBoxScript=true
    fi

    # Call rootAVD with AddRCscripts to add custom *.rc scripts into ramdisk.img/sbin/*.rc
    if has_argument "AddRCscripts" "$@"; then
        AddRCscripts=true
    fi

    RAMDISKIMG=true

    case ${2:-} in
        "restore")
            restore=true
            ;;

        "InstallKernelModules")
            InstallKernelModules=true
            ;;

        "InstallPrebuiltKernelModules")
            InstallPrebuiltKernelModules=true
            ;;
    esac

    # Call rootAVD with BLUESTACKS if you want to patch the ramdisk.img of a BlueStacks System
    if has_argument "BLUESTACKS" "$@"; then
        BLUESTACKS=true
        RAMDISKIMG=false
    fi

    # Call rootAVD with toggleRamdisk if you want to toggle between patched and original ramdisk.img
    if has_argument "toggleRamdisk" "$@"; then
        toggleRamdisk=true
    fi

    # Call rootAVD with FAKEBOOTIMG if you want to create a fake boot.img to patch the ramdisk.img via direct install
    if has_argument "FAKEBOOTIMG" "$@"; then
        FAKEBOOTIMG=true
    fi

    export DEBUG
    export PATCHFSTAB
    export GetUSBHPmodZ
    export RAMDISKIMG
    export restore
    export InstallKernelModules
    export InstallPrebuiltKernelModules
    export ListAllAVDs
    export InstallApps
    export UpdateBusyBoxScript
    export AddRCscripts
    export BLUESTACKS
    export toggleRamdisk
    export SOURCING
    export FAKEBOOTIMG
}
