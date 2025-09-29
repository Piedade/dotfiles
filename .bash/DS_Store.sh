
delete_DS_Store(){
    # if [ -z "$1" ]; then
    #     find . -name '.DS_Store' -delete
    # else
    #     find "$1" -name '.DS_Store' -delete
    # fi
    if [ -z "$1" ]; then
        find . -name '.DS_Store' -print0 | while IFS= read -r -d $'\0' file; do
            echo_info "Deleting: $file"
            rm "$file"
        done
    else
        find "$1" -name '.DS_Store' -print0 | while IFS= read -r -d $'\0' file; do
            echo_info "Deleting: $file"
            rm "$file"
        done
    fi
}
