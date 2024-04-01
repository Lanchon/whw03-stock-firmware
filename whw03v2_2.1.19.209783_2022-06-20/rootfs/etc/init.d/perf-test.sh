#!/bin/sh
setkrait_perf() {
    echo "userspace" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 
    echo "userspace" > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor 
    echo "1400000" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_setspeed 
    echo "1400000" > /sys/devices/system/cpu/cpu1/cpufreq/scaling_setspeed 
    echo 0 > /proc/sys/dev/nss/clock/auto_scale 
    echo 733000000 > /proc/sys/dev/nss/clock/current_freq 
}
setnonkrait_perf() {
    echo "performance" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 
    echo "performance" > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor 
    echo "performance" > /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor 
    echo "performance" > /sys/devices/system/cpu/cpu3/cpufreq/scaling_governor 
    echo "710000" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
    echo "710000" > /sys/devices/system/cpu/cpu1/cpufreq/scaling_min_freq
    echo "710000" > /sys/devices/system/cpu/cpu2/cpufreq/scaling_min_freq
    echo "710000" > /sys/devices/system/cpu/cpu3/cpufreq/scaling_min_freq
}
product=`cat /etc/product`
if [ $product == "wraith" ] || [ $product == "macan" ]; then
    setkrait_perf
else
    setnonkrait_perf
fi
