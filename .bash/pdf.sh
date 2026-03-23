#!/bin/bash

merge_pdf() {
    local output="$1"
    shift

    if [ -z "$output" ] || [ "$#" -eq 0 ]; then
        echo_info "Usage: merge_pdf output.pdf input1.pdf input2.pdf [...]"
        return 1
    fi

    # Check extension .pdf
    [[ "$output" != *.pdf ]] && output="${output}.pdf"

    # Check if files exist
    for f in "$@"; do
        if [ ! -f "$f" ]; then
            echo_error "File not found: $f"
            return 1
        fi
    done

    # Merge with Ghostscript
    gs -dBATCH -dNOPAUSE -q \
       -sDEVICE=pdfwrite \
       -sOutputFile="$output" \
       "$@"

    echo_success "Merged into: $output"
}
