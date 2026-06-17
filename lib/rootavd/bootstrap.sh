# shellcheck shell=bash

getdir() {
    case "$1" in
        */*)
            dir=${1%/*}
            [ -z "$dir" ] && echo "/" || echo "$dir"
            ;;
        *) echo "." ;;
    esac
}

abort_script() {
    echo "[!] aborting the script"
    exit 1
}

has_argument() {
    local expected="$1"
    local argument=""
    shift

    for argument in "$@"; do
        if [ "$argument" = "$expected" ]; then
            return 0
        fi
    done

    return 1
}

rootavd_module_files() {
    cat << 'ROOTAVD_MODULES'
log.sh
backups.sh
args.sh
platform.sh
adb.sh
apps.sh
magisk_downloads.sh
magisk_prepare.sh
ramdisk.sh
ramdisk_fake_boot.sh
kernel_modules.sh
bluestacks_loader_template.sh
bluestacks.sh
help.sh
main.sh
ROOTAVD_MODULES
}

rootavd_load_modules() {
    if [ "${ROOTAVD_BUNDLED:-false}" = "true" ]; then
        return 0
    fi

    if [ -z "${ROOTAVD_LIB_DIR:-}" ]; then
        echo "[!] ROOTAVD_LIB_DIR is not set" >&2
        return 1
    fi

    while IFS= read -r rootavd_module; do
        [ -n "$rootavd_module" ] || continue
        rootavd_module_path="$ROOTAVD_LIB_DIR/$rootavd_module"
        if [ ! -r "$rootavd_module_path" ]; then
            echo "[!] Missing rootAVD module: $rootavd_module_path" >&2
            echo "[!] Run from a complete checkout or use the generated bundle." >&2
            return 1
        fi
        # shellcheck source=/dev/null
        . "$rootavd_module_path"
    done << ROOTAVD_MODULE_LIST
$(rootavd_module_files)
ROOTAVD_MODULE_LIST
}
