#!/bin/bash
#---------------------------------------------------------------------------------
# This script is to set up connections between linux servers via RSA configuration
# This needs dependency of openssh and gnu-opt
# University of Copenhagen
# 2020/12/08
# Yan Hui
# huiyan@food.ku.dk
#---------------------------------------------------------------------------------

# Wrapped function, e.g. usage()
usage () {
    echo ""
    echo "Note: This script sets up connections between servers via a RSA key"
    echo "Usage: $0 [-r -h]"
    echo "  -r, --remote-address    Required, remote host address. Format: user@hostname | host"
    echo "  -h, --help    Optional, Help message."   
    echo ""
    echo "Example: $0 -r server@10.61.11.11"
    echo ""
    echo "Please first prepare one configure file at $HOME/.ssh/config. The format is as follow:"
    echo "Host server"
    echo "Hostname 10.61.11.11"
    echo "User server"
    echo "IdentityFile ~/.ssh/id_rsa"
    echo "";}

#############################################################################
# Check input, ensure alphabet/numbers behind -/--, and at least one option
if [ $# -eq 0 ] || ! [[ $* =~ ^(-|--)[a-z] ]]; then 
    echo "Invalid use: please check the help message below." ; usage; exit 1; fi
# Params loading
args=$(getopt --long "remote-address:,help" -o "r:h" -n "Input error" -- "$@")
# Ensure corrected input of params
if [ $? -ne 0 ]; then usage; exit 1; fi

eval set -- "$args"

while true; do
        case "$1" in
                -r|--remote-address) REMOTE_HOST="$2"; shift 1;;
                -h|--help) usage; exit 1; shift 1;;
                *) break;;    
        esac
done
#############################################################################
# SSH RSA configuration
export PUBKEYPATH="$HOME/.ssh/id_rsa.pub"

echo "$REMOTE_HOST"
if [ ! -f "$PUBKEYPATH" ]; then
    ssh-keygen -t rsa -f "$HOME/.ssh/id_rsa" -q -P ""
fi

# complete the ssh configure file
ssh-copy-id -i "$PUBKEYPATH" "$REMOTE_HOST"

exit 0
