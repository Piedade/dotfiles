#!/bin/bash

echo_info()    { echo -e "\033[1;34m[INFO]\033[0m $1"; }
echo_success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
echo_error()   { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

ensure_dir() {
    [ ! -d "$1" ] && mkdir -p "$1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}
