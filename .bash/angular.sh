#!/bin/bash

# Load Angular CLI autocompletion.
# if angular is installed source, else ignore
if command -v ng &> /dev/null
then
    source <(ng completion script)
fi
