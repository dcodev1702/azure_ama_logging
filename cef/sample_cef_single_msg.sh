#!/bin/bash

SYSLOG_PORT=20514
IPAddress=$(hostname -I | awk '{print $1}')

logger -p local5.info --rfc3164 --tcp -t CEF "0|MFCC-DCO|CYBER-DTF|17.05.1775|Remote Executable Code was Detected|Advanced S-CPT Warfare Planner Maj JJ Bottles detected|100|src=199.3.6.26 spt=3082 dst=20.14.8.24 dpt=1705" -P $SYSLOG_PORT  -n "$IPAddress"
