
delete_DS_Store(){
    # Define o diretório alvo: se passar argumento usa-o, caso contrário usa o diretório atual (.)
    TARGET_DIR="${1:-.}"

    # O uso de \( -name '.DS_Store' -o -name '._*' \) serve como um "OU" (OR) no find
    find "$TARGET_DIR" -type f \( -name '.DS_Store' -o -name '._.DS_Store' \) -print0 | while IFS= read -r -d $'\0' file; do
        echo_info "Deleting: $file"
        rm "$file"
    done
}
