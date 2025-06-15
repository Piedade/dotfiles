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
