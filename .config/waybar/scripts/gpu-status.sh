#!/bin/bash
# AMD GPU usage from sysfs
usage=$(cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null)
[ -z "$usage" ] && usage="N/A"

printf '%3s%%\n' "$usage"
