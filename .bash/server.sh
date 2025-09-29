#!/bin/bash

server(){
    if [ -z "$1" ]; then
        echo -e "${RED}No user account defined!$RESET"
    else
        ACCOUNT="$1"
        echo -e "${BOLD}${RED}*************************"
        echo -e "${RED}* RED - Production server"
        echo -e "${RED}*************************$RESET"
        ssh -p45693 $ACCOUNT@server.red-agency.pt
    fi
}

echo_production_warning() {
    echo -ne "${BOLD}${RED}Are you sure you want to deploy to PRODUCTION? [y/N] ${RESET}"
    read answer

    case "$answer" in
        [Yy]) ;; # echo "Deploying...";;
        *) echo "Aborted."; exit 1;;
    esac
}

export -f echo_production_warning
