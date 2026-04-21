#!/bin/bash

convert_ttf_woff2() {
    # Folder containing the TTF fonts (current directory)
    FONT_DIR="$(pwd)"

    # Output folder
    OUTPUT_DIR="$FONT_DIR/woff2"
    mkdir -p "$OUTPUT_DIR"

    # Loop over all TTF files
    for f in "$FONT_DIR"/*.ttf; do
        [ -f "$f" ] || continue
        filename=$(basename "$f" .ttf)
        woff2_compress "$f"
        mv "$FONT_DIR/$filename.woff2" "$OUTPUT_DIR/$filename.woff2"
        echo "Converted $f → $OUTPUT_DIR/$filename.woff2"
    done

    echo "✅ All fonts converted!"
}
