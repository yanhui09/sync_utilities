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
    echo "Usage: $0 [--preset -n -t --f5h --fqh --rf5d --rfqd --lf5d --lfqd -h]"
    echo "  -p, --preset    Use the preset arguments in the script (Initial settings at KU FOOD)"
    echo "  -n, --nprun    Coupled with -p, nanopore run name to sync"
    echo "  -t, --wait    overwrite -p if applied, waiting time to exit, second(s). Default. -t 900: Exit if no new fastq files within 15 min"
    echo "  -s, --f5h    overwrite -p if applied, fast5 host. Format: user@hostname | host"
    echo "  -k, --fqh    overwrite -p if applied, fastq host. Format: user@hostname | host"
    echo "  -a --rf5d    overwrite -p if applied, absolute path for fast5 directory on remote host"
    echo "  -d, --rfqd    overwrite -p if applied, absolute path for fastq directory on remote host"
    echo "  -j, --lf5d    overwrite -p if applied, absolute/relative path for fast5 directory on the local host"
    echo "  -l, --lfqd    overwrite -p if applied, absolute/relative path for fastq directory on the local host"
    echo "  --f5local    overwrite -p if applied, sync fast5 locally (mounted SMB disk), mtime not preserved"
    echo "  --fqlocal    overwrite -p if applied, sync fastq locally (mounted SMB disk), mtime not preserved"
    echo "  -h, --help    Optional, Help message."   
    echo ""
    echo "Example:" 
    echo "$0 -p -n minion_x"
    echo "$0 -p -n minion_x --fqh fq_host2 -t 1800"
    echo ""
    echo "";}

#############################################################################
# Check input, ensure alphabet/numbers behind -/--, and at least one option
if [ $# -eq 0 ] || ! [[ $* =~ ^(-|--)[a-z] ]]; then 
    echo "Invalid use: please check the help message below." ; usage; exit 1; fi
# Params loading
args=$(getopt --long "preset,nprun:,wait:,f5h:,fqh:,rf5d:,rfqd:,lf5d:,lfqd:,help" -o "pn:t:s:k:a:d:j:l:h" -n "Input error" -- "$@")
# Ensure corrected input of params
if [ $? -ne 0 ]; then usage; exit 1; fi

eval set -- "$args"

while true ; do
        case "$1" in
                -n|--nprun) NP_RUN="$2"; shift 2;;
                -t|--wait) WAIT="$2"; shift 2;;
                -s|--f5h) F5_HOST="$2"; shift 2;;
                -k|--fqh) FQ_HOST="$2"; shift 2;;
                -a|--rf5d) RF5_DIR="$2"; shift 2;;
                -d|--rfqd) RFQ_DIR="$2"; shift 2;;
                -j|--lf5d) LF5_DIR="$2"; shift 2;;
                -l|--lfqd) LFQ_DIR="$2"; shift 2;;
                --f5local) F5_LOCAL=true; shift 1;;
                --fqlocal) FQ_LOCAL=true; shift 1;;
                -p|--preset) PRESET=true; shift 1;; # Indicator changed
                -h|--help) usage; exit 1; shift 1;;
                *) break;;    
        esac
done
#############################################################################
# Paratermer initialization
# preset arguments will be overwritten if -t, --f5h, --fqh, --rf5d, --rfqd, --lf5d, --lfqd applied
if [ "$PRESET" == true ]; then
   if [ -z "$WAIT" ]; then
    WAIT=900    # default waiting time at KU FOOD
   fi
   if [ -z "$F5_HOST" ]; then
    F5_HOST=localhost    # default fast5 host at KU FOOD
   fi
   if [ -z "$FQ_HOST" ]; then
    FQ_HOST=krakenosh   # default fastq host at KU FOOD
   fi
   if [ -z "$RF5_DIR" ]; then
   # default path of remote fast5 directory at KU FOOD, smb disk 
    #RF5_DIR="/run/user/1000/gvfs/smb-share:server=science.domain,share=groupdirs/SCIENCE-FOOD-HTS-STORAGE/ONT-data/FAST5-storage/$NP_RUN"
    RF5_DIR="/run/user/1000/gvfs/dav:host=io.erda.dk,ssl=true/ONT/FAST5_storage/$NP_RUN"    
   fi
   if [ -z "$RFQ_DIR" ]; then
    RFQ_DIR="/media/krakenosh/25289ce3-5e4b-4a16-821a-c95942864847/LUKASZ/ONT/GridION_fq_storage/$NP_RUN"    # default path of remote fastq directory (to be demultiplexed) at KU FOOD
   fi
   if [ -z "$LF5_DIR" ]; then
    LF5_DIR=$(find "/data/$NP_RUN" -type d -name fast5_pass)    # default path of local fast5 directory at KU FOOD
   fi
   if [ -z "$LFQ_DIR" ]; then
    LFQ_DIR=$(find "/data/$NP_RUN" -type d -name fastq_pass)    # default path of local fastq directory at KU FOOD
   fi
   if [ -z "$F5_LOCAL" ]; then
    F5_LOCAL=true    # we use mounted SMB disk for FASTA5 at KU FOOD
   fi
   if [ -z "$FQ_LOCAL" ]; then
    FQ_LOCAL=false    # we use private servcer for FASTQ at KU FOOD
   fi
fi

# benchmark on personal server
#F5_HOST=localhost
#FQ_HOST=yichang
#RF5_DIR="/home/yanhui/sharedFatboy/backup_ku/hdrive/sync_test/$NP_RUN" # test 
#RFQ_DIR="/mnt/raid5/yanhui/sync_test/$NP_RUN/fastq4DEMUX" 
#LF5_DIR=$(find "$HOME/Sdevelop/sync_utilities/sync_test/$NP_RUN" -type d -name fast5_pass)
#LFQ_DIR=$(find "$HOME/Sdevelop/sync_utilities/sync_test/$NP_RUN" -type d -name fastq_pass)


# check if $LF5_DIR and $LFQ_DIR exist in the local host (nanopore sequencer)  
if [[ ! -d "$LF5_DIR" || ! -d "$LFQ_DIR" ]]; then
    echo "Can't find the local fast5 and fastq directory. Please check if they exist at the sequencing host."
    exit 1
fi

# check if $NP_RUN (the nanopre run directory) has been created in the fast5 and fastq host
dir_check(){
    local __HOST=$1
    local __RDIR=$2
    if ssh $__HOST "[ -d $__RDIR ]"; then
       echo "Warning: The $__RDIR existed in the host."
       echo "No worry. The existing files will be ignored. :)"
       echo "Consider renaming the run direcotry locally if you need."
    fi
}

dir_check $F5_HOST $RF5_DIR
dir_check $FQ_HOST $RFQ_DIR

# create the remote fast5 and fastq directory
ssh $F5_HOST "mkdir -p $RF5_DIR"
ssh $FQ_HOST "mkdir -p $RFQ_DIR"


# use rsync to avoid repetively transfering files. With -P option to resume the transfer if it is interupted.
# substitute scp
# fastq files come after fast5 due to the process of basecalling

rsync_make(){
    local __LOCAL=$1
    local __LDIR=$2
    local __RDIR=$3
    local __HOST=$4
    local __RSYNC_CMD
    if [ "$__LOCAL" == true ]; then
        __RSYNC_CMD="rsync -hvrP --ignore-existing ${__LDIR} ${__RDIR}"
    else
        __RSYNC_CMD="rsync -hvrtPe ssh ${__LDIR} ${__HOST}:${__RDIR}"
    fi
    eval $__RSYNC_CMD
}

while
    #rsync -hvrtPe ssh "$LFQ_DIR/" "$FQ_HOST:$RFQ_DIR"
    #rsync -hvrtPe ssh "$LF5_DIR/" "$F5_HOST:$RF5_DIR"
    rsync_make $FQ_LOCAL $LFQ_DIR $RFQ_DIR $FQ_HOST
    rsync_make $F5_LOCAL $LF5_DIR $RF5_DIR $F5_HOST
    inotifywait -e modify,create -t "$WAIT" "$LFQ_DIR" 
do true ; done

exit 0
