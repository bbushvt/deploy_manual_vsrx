#!/usr/bin/env bash
physFuncts=()

cd '/sys/class/net'

echo -n 'Finding interfaces... '
for device in *; do
        if [ -e "${device}/device/sriov_numvfs" ]; then physFuncts+=("${device}"); fi
done
echo "done."

for interface in "${physFuncts[@]}"; do
    num_vfs="$(cat /sys/class/net/${interface}/device/sriov_numvfs)"

    for ((vf = 0; vf < num_vfs; vf++)); do
        echo "Disabling spoof checking and enabling trust for physical function: ${interface} vf ${vf}... "
        ip link set "${interface}" vf "${vf}" spoofchk off
        ip link set "${interface}" vf "${vf}" trust on
    done
    echo "done."
done
