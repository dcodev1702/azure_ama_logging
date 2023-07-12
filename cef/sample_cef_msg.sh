#!/bin/bash

logger -p local5.info --rfc3164 --tcp -t CEF "0|MFCC-DCO|CYBER-DTF|17.02.1775|Remote Executable Code was Detected|Advanced S-CPT Warfare Planner Maj JJ Bottles detected|100|src=199.3.6.26 spt=3082 dst=20.14.8.24 dpt=1702" -P 514  -n 127.0.0.1
