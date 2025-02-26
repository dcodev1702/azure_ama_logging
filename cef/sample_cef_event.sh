#!/bin/bash

SYSLOG_PORT=514
IPAddress=$(hostname -I | awk '{print $1}')

# Array of CEF log messages
log_messages=(
    "0|MFCC-DOG|CYBER-DTF|17.02.1775|Remote Executable Code was Detected|Advanced 651 CPT TL (Capt GNU Compiler) detected|100|src=$IPAddress spt=46117 dst=20.14.8.24 dpt=1702"
    "0|MFCC-DOG|CYBER-DTF|17.99.1775|Remote Executable Code was Detected|Advanced 651 CPT SEL (MSGT Cloud Forensicator) detected|100|src=$IPAddress spt=46117 dst=20.14.8.24 dpt=1799"
    "0|MFCC-DOG|CYBER-DTF|17.05.1775|Remote Executable Code was Detected|Advanced 651 CPT CWP (Maj JJ Bottles) detected|100|src=$IPAddress spt=46117 dst=20.14.8.24 dpt=1705"
)

# Function to log a message
log_message() {
    local message="$1"
    logger -p local5.info --rfc3164 --tcp -t CEF "$message" -P $SYSLOG_PORT -n $IPAddress
}

# Iterate over the array and log each message
for msg in "${log_messages[@]}"; do
    log_message "$msg"
done
