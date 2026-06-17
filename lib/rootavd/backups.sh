# shellcheck shell=bash

checkfile() {
    #echo "checkfile $1"
    if [ -r "$1" ]; then
        #echo "File exists and is readable"
        if [ -s "$1" ]; then
            #echo "and has a size greater than zero"
            if [ -w "$1" ]; then
                #echo "and is writable"
                if [ -f "$1" ]; then
                    #echo "and is a regular file."
                    return 1
                fi
            fi
        fi
    fi
    return 0
}

create_backup() {
    local FILE=""
    local FILEPATH=""
    local FILENAME=""
    local BACKUPFILE=""
    FILE="$1"
    FILEPATH=${FILE%/*}
    FILENAME=${FILE##*/}
    BACKUPFILE="$FILENAME.backup"

    cd "$FILEPATH" > /dev/null || return
    # If no backup file exist, create one
    if checkfile "$BACKUPFILE"; then
        echo "[*] create Backup File of $FILENAME"
        cp "$FILENAME" "$BACKUPFILE"
    else
        echo "[-] $FILENAME Backup exists already"
    fi
    cd - > /dev/null || return
}

restore_backups() {
    local BACKUPFILE=""
    local RESTOREFILE=""
    local BACKUPFILES=""

    BACKUPFILES=$(find "$1" -type f -name '*.backup')

    if [ "$BACKUPFILES" == "" ]; then
        echo "[*] No Backup(s) to restore"
    else
        echo "$BACKUPFILES" | while IFS= read -r BACKUPFILE; do
            RESTOREFILE="${BACKUPFILE%.backup}"
            echo "[!] Restoring ${BACKUPFILE##*/} to ${RESTOREFILE##*/}"
            cp "$BACKUPFILE" "$RESTOREFILE"
        done
        echo "[*] Backups still remain in place"
    fi
    return 0
}

toggle_Ramdisk() {

    #AVDPATHWITHRDFFILE="$1"
    #AVDPATH=${AVDPATHWITHRDFFILE%/*}
    #RDFFILE=${AVDPATHWITHRDFFILE##*/}
    #RESTOREPATH=$AVDPATH

    local RamdiskFile="$AVDPATHWITHRDFFILE"
    local PatchedFile="$AVDPATHWITHRDFFILE.patched"
    local BackupFile="$AVDPATHWITHRDFFILE.backup"

    if checkfile "$BackupFile"; then
        echo "[!] we need a valid backup file to proceed"
        return 0
    fi

    echo "[-] Toggle Ramdisk"
    if checkfile "$PatchedFile"; then
        echo "[*] Pushing patched Ramdisk into Stack"
        mv "$RamdiskFile" "$PatchedFile"
        echo "[*] Popping original Ramdisk from Backup"
        cp "$BackupFile" "$RamdiskFile"
    else
        echo "[*] Popping patched Ramdisk back from Stack"
        mv -f "$PatchedFile" "$RamdiskFile"
    fi
    return 0
}
