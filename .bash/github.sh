#!/bin/bash

# Function to zip the last commit files
zipLastCommitFiles(){
    if [ -z ${1+x} ]; then
        commit_id=$(git rev-parse HEAD 2> /dev/null)
    else
        commit_id=$1
    fi

    if [[ -n $commit_id ]]; then
        echo "Commit: $commit_id"
        commit_name="[$(git rev-parse --short $commit_id 2> /dev/null)] $(git show-branch --no-name $commit_id 2> /dev/null | sed -e 's/\//+/g')"
        git diff-tree -r --no-commit-id --name-only --diff-filter=ACMRT $commit_id | tar -czf ../$commit_name.tgz -T -
        echo "${BOLD}${GREEN}DONE: ../$commit_name.tgz$RESET"
    else
        echo "${BOLD}${RED}No commits here...$RESET"
    fi
}
