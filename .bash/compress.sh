#!/bin/bash

compress() {
    local FOLDER="$1"

    if [ -z "$FOLDER" ]; then
        echo_error "Usage: compress <folder_name>"
        return 1
    fi

    if [ ! -d "$FOLDER" ]; then
        echo_error "Folder not found: $FOLDER"
        return 1
    fi

    local FOLDER_NAME
    FOLDER_NAME="$(basename "$FOLDER")"
    local OUT="$FOLDER_NAME.tar.zst"

    echo_info "A calcular tamanho de '$FOLDER'..."
    local SIZE
    SIZE="$(du -sb "$FOLDER" | cut -f1)"

    tar -cf - -C "$(dirname "$FOLDER")" "$FOLDER_NAME" \
        | pv -s "$SIZE" \
        | zstd -q -T0 -o "$OUT"

    if [ $? -eq 0 ]; then
        echo_success "Created $OUT"
    else
        echo_error "Failed to compress '$FOLDER'."
        return 1
    fi
}
export -f compress
