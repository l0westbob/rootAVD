# shellcheck shell=bash

info() {
    echo "[*] $*"
}

warn() {
    echo "[-] $*"
}

error() {
    echo "[!] $*" >&2
}

question() {
    echo "[?] $*"
}
