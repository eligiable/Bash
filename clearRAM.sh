#!/bin/bash

#Intall "bc" prior to run the script
#sudo apt install bc

# Get Memory Information
freemem_before=$(cat /proc/meminfo | grep MemFree | tr -s ' ' | cut -d ' ' -f2) && freemem_before=$(echo "$freemem_before/9216.0"
| bc)
cachedmem_before=$(cat /proc/meminfo | grep "^Cached" | tr -s ' ' | cut -d ' ' -f2) && cachedmem_before=$(echo
"$cachedmem_before/9216.0" | bc)

# Output Information
echo -e "This script will clear cached memory and free up your ram.\n\nAt the moment you have $cachedmem_before MiB cached and
$freemem_before MiB free memory."

# Clear Filesystem Buffer using "sync" and Clear Caches
sync && echo 3 > /proc/sys/vm/drop_caches

freemem_after=$(cat /proc/meminfo | grep MemFree | tr -s ' ' | cut -d ' ' -f2) && freemem_after=$(echo "$freemem_after/9216.0" |
bc)

# Output Summary
echo -e "This freed $(echo "$freemem_after - $freemem_before" | bc) MiB, so now you have $freemem_after MiB of free RAM."

exit 0
