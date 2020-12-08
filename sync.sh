#!/bin/bash
#---------------------------------------------------------------------------------
# This script is to sync files by ssh after RSA configuration
# This needs dependency of openssh 
# University of Copenhagen
# 2020/12/08
# Yan Hui
# huiyan@food.ku.dk
#---------------------------------------------------------------------------------

# Wrapped function, e.g. usage()
usage () {
    echo ""
    echo "Note: This script sync files between servers configured by RSA keys."
    echo "It backs up the local fast5 and fastq files to remote hosts storing fast5 and fastq files"
    echo "Usage: $0 [--preset -f5h --fast5-host -fqh --fastq-host -rf5d --remote-fast5_directory -rfqd --remote-fastq_directory -lf5d --local-fast5_directory -lfqd --local-fastq_directory]"
    echo "  --preset    use the preset arguments in the script (initailly set for KU FOOD servers)"
    echo "  -n, --nanopore-run_name    Required, nanopore run name to sync"
    echo "  -f5h, --fast5-host    Required if no --preset, fast5 host. Format: user@hostname | host"
    echo "  -fqh, --fastq5-host    Required if no --preset, fastq host. Format: user@hostname | host"
    echo "  -rfqd, --remote-fast5_directory    Required if no --preset, fast5 directory path on remote host"
    echo "  -rfqd, --remote-fastq_directory    Required if no --preset, fastq directory path on remote host"
    echo "  -lf5d, --local-fast5_directory    Required if no --preset, fast5 directory path on the local host"
    echo "  -lfqd, --local-fastq_directory    Required if no --preset, fastq directory path on the local host"
    echo "  -h, --help    Optional, Help message."   
    echo ""
    echo "Example: $0 --preset -n minion_35"
    echo ""
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

