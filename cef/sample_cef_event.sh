#!/bin/bash

PORT=514
IP=192.168.10.224

# Array of base log messages
log_messages=(
    "0|MFCC-DOG|CYBER-DTF|17.02.1775|Remote Executable Code was Detected|Advanced 651 CPT TL (Capt GNU Compiler) detected|100|src=192.168.10.170 spt=46117 dst=20.14.8.24 dpt=1702"
    "0|MFCC-DOG|CYBER-DTF|17.99.1775|Remote Executable Code was Detected|Advanced 651 CPT SEL (MSGT Cloud Forensicator) detected|100|src=192.168.10.170 spt=46117 dst=20.14.8.24 dpt=1799"
    "0|MFCC-DOG|CYBER-DTF|17.05.1775|Remote Executable Code was Detected|Advanced 651 CPT CWP (Maj JJ Bottles) detected|100|src=192.168.10.170 spt=46117 dst=20.14.8.24 dpt=1705"
)

# Function to log a message
log_message() {
    local message="$1"
    logger -p local5.info --rfc3164 --tcp -t CEF "$message" -P $PORT -n $IP
}

# Iterate over the array and log each message
for msg in "${log_messages[@]}"; do
    log_message "$msg"
done
