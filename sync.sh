#!/bin/bash
#---------------------------------------------------------------------------------
# This script is to sync files by ssh after RSA configuration
# This needs dependency of openssh, getopt, rsync, inotify
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
    echo ""
    echo "Usage: $0 [--preset -n --f5h --fqh --rf5d --rfqd --lf5d --lfqd -h]"
    echo "  -p, --preset    Use the preset arguments in the script (Initial settings at KU FOOD)"
    echo "  -n, --nprun    Coupled with -p, nanopore run name to sync"
    echo "  -s, --f5h    Required if no --preset, fast5 host. Format: user@hostname | host"
    echo "  -k, --fqh    Required if no --preset, fastq host. Format: user@hostname | host"
    echo "  -a --rf5d    Required if no --preset, absolute path for fast5 directory on remote host"
    echo "  -d, --rfqd    Required if no --preset, absolute path for fastq directory on remote host"
    echo "  -j, --lf5d    Required if no --preset, absolute/relative path for fast5 directory on the local host"
    echo "  -l, --lfqd    Required if no --preset, absolute/relative path for fastq directory on the local host"
    echo "  -h, --help    Optional, Help message."   
    echo ""
    echo "Example:" 
    echo "$0 -p -n minion_x"
    echo "$0 -p -n minion_x --fqh fq_host2"
    echo ""
    echo "";}

#############################################################################
# Check input, ensure alphabet/numbers behind -/--, and at least one option
if [ $# -eq 0 ] || ! [[ $* =~ ^(-|--)[a-z] ]]; then 
    echo "Invalid use: please check the help message below." ; usage; exit 1; fi
# Params loading
args=$(getopt --long "preset,nprun:,f5h::,fqh::,rf5d::rfqd::,lf5d::,lfqd::,help" -o "pn:s::k::a::d::j::l::h" -n "Input error" -- "$@")
# Ensure corrected input of params
if [ $? -ne 0 ]; then usage; exit 1; fi

eval set -- "$args"

while true ; do
        case "$1" in
                -n|--nprun) NP_RUN="$2"; shift 1;;
                -s|--f5h) F5_HOST="$2"; shift 2;;
                -k|--fqh) FQ_HOST="$2"; shift 2;;
                -a|--rf5d) RF5_DIR="$2"; shift 2;;
                -d|--rfqd) RFQ_DIR="$2"; shift 2;;
                -j|--lf5d) LF5_DIR="$2"; shift 2;;
                -l|--lfqd) LFQ_DIR="$2"; shift 2;;
                -p|--preset) PRESET=true, shift 1;; # Indicator changed
                -h|--help) usage; exit 1; shift 1;;
                *) break;;    
        esac
done
#############################################################################
# Paratermer initialization
# preset arguments will be overwritten if --f5h, --fqh, --rf5d, --rfqd, --lf5d, --lfqd applied
if [ "$PRESET" == true ]; then
   if [ -z "$F5_HOST" ]; then
    F5_HOST=localhost    # default fast5 host at KU FOOD
   fi
   if [ -z "$FQ_HOST" ]; then
    FQ_HOST=lubuntu   # default fastq host at KU FOOD
   fi
   if [ -z "$RF5_DIR" ]; then
   # default path of remote fast5 directory at KU FOOD, smb disk 
    RF5_DIR="/run/user/1000/gvfs/smb-share:server=science.domian,share=groupdirs/SCIENCE-FOOD-HTS-STORAGE/ONT-data/FASTA5-storage/$NP_RUN"    
   fi
   if [ -z "$RFQ_DIR" ]; then
    RFQ_DIR="/data/$NP_RUN/fastq4DEMUX"    # default path of remote fastq directory (to be demultiplexed) at KU FOOD
   fi
   if [ -z "$LF5_DIR" ]; then
    LF5_DIR=$(find "/data/$NP_RUN" -type d -name fast5_pass)    # default path of local fast5 directory at KU FOOD
   fi
   if [ -z "$LFQ_DIR" ]; then
    LFQ_DIR=$(find "/data/$NP_RUN" -type d -name fastq_pass)    # default path of local fastq directory at KU FOOD
   fi
fi

# benchmark on personal server
F5_HOST=localhost
FQ_HOST=yichang
RF5_DIR="/home/yanhui/sharedFatboy/backup_ku/hdrive/sync_test/$NP_RUN" # test 
RFQ_DIR="/mnt/raid5/yanhui/sync_test/$NP_RUN/fastq4DEMUX" 
LF5_DIR=$(find "$HOME/Sdevelop/sync_utilities/sync_test/$NP_RUN" -type d -name fast5_pass)
LFQ_DIR=$(find "$HOME/Sdevelop/sync_utilities/sync_test/$NP_RUN" -type d -name fastq_pass)
# check if $LF5_DIR and $LFQ_DIR exist in the local host (nanopore sequencer)  
if [[ ! -d "$LF5_DIR" || ! -d "$LFQ_DIR" ]]; then
    echo "Can't find the local fast5 and fastq directory. Please check if they exist at the sequencing host."
    exit 1
fi

# double-check if $NP_RUN (the nanopre run directory) has been created in the fast5 and fastq host
# to avoid data overwriting due to wrong type-in
# if the directory has been created, prompt a warning to confirm whether to proceed sync.
if ssh "$F5_HOST" "[ -d \$RF5_DIR ]"; then
    echo "The $RF5_DIR has already existed at $F5_HOST."
    read -pr "Assign a new remote fast5 directory (Abosulte path) or press enter to continue:" RF5_DIR_NEW
    if [ -n "$RF5_DIR_NEW" ]; then
        RF5_DIR="$RF5_DIR_NEW"
    fi    
elif ssh "$FQ_HOST" "[ -d \$RFQ_DIR ]"; then
    echo "The $RFQ_DIR has already existed at $FQ_HOST."
    read -pr "Assign a new remote fastq directory (Abosulte path) or press enter to continue:" RFQ_DIR_NEW
    if [ -n "$RFQ_DIR" ]; then
        RFQ_DIR="$RFQ_DIR_NEW"
    fi    
else # create the remote fast5 and fastq directory
    ssh "$F5_HOST" mkdir -p "$RF5_DIR"
    ssh "$FQ_HOST" mkdir -p "$RFQ_DIR"
fi

# use rsync to avoid repetively transfering files. With -P option to resume the transfer if it is interupted.
# substitute scp
# fastq files come after fast5 due to the process of basecalling

while 
    rsync -hvrtPe ssh "$LFQ_DIR/" "$FQ_HOST@$RFQ_DIR"
    rsync -hvrtPe ssh "$LF5_DIR/" "$F5_HOST@$RF5_DIR"
    inotifywait -e modify,create -t 900 "$LFQ_DIR" 
do true ; done

exit 0
