#!/bin/bash

# Bind Ctrl+k to clear terminal
bind '"\C-k": "\C-e\C-u clear\n"'

# Function to check and display file or directory permissions
permission() {
    if [ -z "$1" ]; then
        echo "Usage: permission <file_or_directory>"
        return 1
    fi

    if [ ! -e "$1" ]; then
        echo "File or directory does not exist: $1"
        return 1
    fi

    stat -c "%a %n" "$1"
}
