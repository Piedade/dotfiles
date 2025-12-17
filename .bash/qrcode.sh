#!/bin/bash

create_qrcode() {
    local URL="$1"
    local OUT="$2"

    if [ -z "$URL" ]; then
        read -p "Enter the URL (e.g., https://example.com): " URL
    fi

    OPTIONS="-s 10 -l H"
    if [ -z "$OUT" ]; then
        qrencode -t ansiutf8 $OPTIONS "$URL"
    else
        [[ "$OUT" != *.png ]] && OUT_PNG="$OUT-qrcode.png"
        qrencode -o "$OUT_PNG" $OPTIONS "$URL"

        [[ "$OUT" != *.svg ]] && OUT_SVG="$OUT-qrcode.svg"
        qrencode -o "$OUT_SVG" -t SVG $OPTIONS "$URL"
    fi

    if [ $? -eq 0 ]; then
        echo_success "QR Code created!"
        echo_info "Podes enviar este texto ao cliente para validar o QR code:"
        echo "Pode validar o QR code? Em anexo encontra duas versões: uma em formato de imagem normal e outra em formato vectorial, que permite aumentar as dimensões sem perder qualidade."
    else
        echo_error "Error: Failed to create qrcode for '$URL'." >&2
        exit 1
    fi
}
