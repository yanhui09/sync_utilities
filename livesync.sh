#!/bin/bash
#---------------------------------------------------------------------------------
# This script is for real-time sync new runs in the monitor path.
# It will automatically call respective sync.sh when one run directory is created at the monitor path.
# So it may get stuck when thousands of files running simultaneously.
# It will start an infinite loop to monitor the input path. So remember to manually stop it if you don't want sync anymore.

# This needs dependency of openssh, getopt, rsync, inotify
# University of Copenhagen
# 2020/12/10
# Yan Hui
# huiyan@food.ku.dk
#---------------------------------------------------------------------------------

# Wrapped function, e.g. usage()
usage () {
    echo ""
    echo "Note: This script calls a sync.sh when a new run is created at the monitor path"
    echo "It starts an infinite loop to monitor the input path. Stop the shell when you don't want monitor the path anymore."
    echo ""
    echo "Usage: $0 [-m -h]"
    echo "  -m, --monitor-path    Required, the monitor path (absolute/relative)."
    echo "  -h, --help    Optional, Help message."   
    echo ""
    echo "Example: $0 -m /dir_all_runs"
    echo "";}

#############################################################################
# Check input, ensure alphabet/numbers behind -/--, and at least one option
if [ $# -eq 0 ] || ! [[ $* =~ ^(-|--)[a-z] ]]; then 
    echo "Invalid use: please check the help message below." ; usage; exit 1; fi
# Params loading
args=$(getopt --long "monitor-path:,help" -o "m:h" -n "Input error" -- "$@")
# Ensure corrected input of params
if [ $? -ne 0 ]; then usage; exit 1; fi

eval set -- "$args"

while true; do
        case "$1" in
                -m|--monitor-path) MONITOR_DIR="$2"; shift 1;;
                -h|--help) usage; exit 1; shift 1;;
                *) break;;    
        esac
done
#############################################################################

while RES=$(inotifywait -e create "$MONITOR_DIR"); do 
    if [[ ! "$RES" =~ "CREATE,ISDIR " ]]; then
       continue
    fi
    RUN_NEW=${RES#?*CREATE,ISDIR }
    printf "Detected a new NP run: %s\n" "$RUN_NEW"
    while true; do 
        sleep 30  # wait files fed to fastq-pass directory
        fastq_pass_DIR=$(find "$MONITOR_DIR/$RUN_NEW" -type d -name "fastq_pass")
        if [ -n "$fastq_pass_DIR" ]; then
            break
        fi
    done
    sync.sh -p -n "$RUN_NEW" & # This may accumulate when previous sync.sh hasn't exited.
done

