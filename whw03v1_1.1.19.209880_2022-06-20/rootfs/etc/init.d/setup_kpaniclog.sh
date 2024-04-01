#!/bin/sh
KVER=`uname -r`
MMC_FOR_PANIC=`syscfg get mmc.for.panic`
MTD_FOR_PANIC=`syscfg get mtd.for.panic`
mmc_for_panic=""
mtd_for_panic=""
if [ -n "$MMC_FOR_PANIC" ]; then
 mmc_for_panic=`cat /proc/partitions| grep $MMC_FOR_PANIC | awk '{print $4}'`
fi
if [ -n "$MTD_FOR_PANIC" ]; then
 mtd_for_panic=`cat /proc/mtd | grep $MTD_FOR_PANIC | awk -F ":" '{print $1}'`
fi
setup_mtd_for_logging()
{
   mtd_offs=`syscfg get mtd.for.panic.offset`
   skip_count=`expr $((mtd_offs)) / 512`
   if [ "$mtd_for_panic" != "" ]; then
       if [ -e /tmp/var/config/panic.md5 ]; then
           dd if=/dev/$mtd_for_panic of=/tmp/panic skip=$skip_count count=256 &> /dev/null
           md5sum /tmp/panic > /tmp/panic.md5
           crash=`diff /tmp/panic.md5 /tmp/var/config/panic.md5`
           if [ "$crash" != "" ]; then
               echo "---------------Crash detected-----------------"
               tr $'\xff' ' ' < /tmp/panic | tr -s ' ' > /tmp/panic.txt
               mv /tmp/panic.txt /tmp/panic
           else
               rm /tmp/panic
           fi
           rm /tmp/panic.md5
       else
       flash_erase -q /dev/$mtd_for_panic $mtd_offs 1 &>/dev/null
       dd if=/dev/$mtd_for_panic of=/tmp/panic skip=$skip_count count=256  &>/dev/null
       md5sum /tmp/panic > /tmp/var/config/panic.md5
       rm /tmp/panic
       fi		
       /sbin/modprobe kpaniclog mtdname=$MTD_FOR_PANIC mtdoffset=$mtd_offs 
   fi
}
setup_mmc_for_logging()
{
   if [ "$mmc_for_panic" != "" ]; then
         if [ -e /tmp/var/config/panic.md5 ]; then
              dd if=/dev/$mmc_for_panic of=/tmp/panic count=256 &> /dev/null
              md5sum /tmp/panic > /tmp/panic.md5
              crash=`diff /tmp/panic.md5 /tmp/var/config/panic.md5`
              if [ "$crash" != "" ]; then
                  echo "---------------Crash detected-----------------"
                  tr $'\xff' ' ' < /tmp/panic | tr -s ' ' > /tmp/panic.txt
                  mv /tmp/panic.txt /tmp/panic
             else
               rm /tmp/panic
             fi
            rm /tmp/panic.md5
          else
            dd if=/dev/zero of=/dev/$mmc_for_panic  &>/dev/null
            dd if=/dev/$mmc_for_panic of=/tmp/panic count=256 &>/dev/null
            md5sum /tmp/panic > /tmp/var/config/panic.md5
            rm /tmp/panic
          fi		
        /sbin/modprobe kpaniclog mmcblk=$MMC_FOR_PANIC
   fi
}
if [ -e /lib/modules/$KVER/kpaniclog.ko ]; then
    if [ -n "$MTD_FOR_PANIC" ] && [ -n "$mtd_for_panic" ]; then
       setup_mtd_for_logging
    else 
        if [ -n "$MMC_FOR_PANIC" ] && [ -n "$mmc_for_panic" ]; then
          setup_mmc_for_logging
        fi
    fi
fi
