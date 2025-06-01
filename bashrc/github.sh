#!/bin/bash

# GitHub CLI login check
if command -v gh >/dev/null 2>&1; then
    if ! gh auth status >/dev/null 2>&1; then
        echo -e "${YELLOW}[GitHub]${WHITE} You are not logged in to GitHub CLI."
        echo -e "${CYAN}Run ${GREEN}gh auth login${CYAN} to authenticate.${WHITE}"
    fi
fi
