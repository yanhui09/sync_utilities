#!/bin/bash
#---------------------------------------------------------------------------------
# This script is to sync files by ssh after RSA configuration
# This needs dependency of openssh, getopt
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
    echo "  -p, --preset    use the preset arguments in the script (initailly set for KU FOOD servers)"
    echo "  -n, --nprun    Required, nanopore run name to sync"
    echo "  -s, --f5h    Required if no --preset, fast5 host. Format: user@hostname | host"
    echo "  -k, --fqh    Required if no --preset, fastq host. Format: user@hostname | host"
    echo "  -a --rf5d    Required if no --preset, fast5 directory path on remote host"
    echo "  -d, --rfqd    Required if no --preset, fastq directory path on remote host"
    echo "  -j, --lf5d    Required if no --preset, fast5 directory path on the local host"
    echo "  -l, --lfqd    Required if no --preset, fastq directory path on the local host"
    echo "  -h, --help    Optional, Help message."   
    echo ""
    echo "Example: $0 -p -n minion_35"
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
    F5_HOST=kuser    # default fast5 host at KU FOOD
   fi
   if [ -z "$FQ_HOST" ]; then
    FQ_HOST=lubuntu   # default fastq host at KU FOOD
   fi
   if [ -z "$RF5_DIR" ]; then
    RF5_DIR=/data/fast5_backup/"$NP_RUN"    # default path of remote fast5 directory at KU FOOD    
   fi
   if [ -z "$RFQ_DIR" ]; then
    RFQ_DIR=/data/"$NP_RUN"/fastq4DEMUX    # default path of remote fastq directory (to be demultiplexed) at KU FOOD
   fi
   if [ -z "$LF5_DIR" ]; then
    LF5_DIR=$(find /data/"$NP_RUN" -type d -name fast5_pass)    # default path of local fast5 directory at KU FOOD
   fi
   if [ -z "$LFQ_DIR" ]; then
    LFQ_DIR=$(find /data/"$NP_RUN" -type d -name fastq_pass)    # default path of local fastq directory at KU FOOD
   fi
fi

# check if $LF5_DIR and $LFQ_DIR exist in the local host (nanopore sequencer)  
if [[ ! -d "$LF5_DIR" || ! -d "$LFQ_DIR" ]]; then
    echo "Can't find the local fast5 and fastq directory. Please check if they exist at the sequencing host."
    exit 1
fi

# double-check if $NP_RUN (the nanopre run directory) has been created in the fast5 and fastq host
# to avoid data overwriting due to wrong type-in
# if the directory has been created, prompt a warning to confirm whether to proceed sync.
if ssh "$F5_HOST" "[ -d \$RF5_DIR ]"; then
    read -pr "The $RF5_DIR has already existed at $F5_HOST.\nAssign a new remote fast5 directory (Abosulte path)\nor press enter to continue:" RF5_DIR_NEW
    if [ -n "$RF5_DIR_NEW" ]; then
        RF5_DIR="$RF5_DIR_NEW"
    fi    
elif ssh "$FQ_HOST" "[ -d \$RFQ_DIR ]"; then
    read -pr "The $RFQ_DIR has already existed at $FQ_HOST.\nAssign a new remote fastq directory (Abosulte path)\nor press enter to continue:" RFQ_DIR_NEW
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

while true ; do
    for file in "$LFQ_DIR"/*fastq; do
        file_id="${file%%.*}"
        rsync -vP "$LFQ_DIR/$file_id.fastq" "$FQ_HOST@$RFQ_DIR/$file_id.fastq"
        rsync -vP "$LF5_DIR/$file_id.fast5" "$F5_HOST@$RF5_DIR/$file_id.fast5"
        # wait for new fastq files
        
        
    done        
done
