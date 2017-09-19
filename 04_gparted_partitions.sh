#!/bin/bash

#boot into root cli for live image (e.g.,gparted.v?.iso)

#unlock the encrypted disk
cryptsetup luksOpen /dev/sda5 cryptdisk

#fsck disk
e2fsck -f /dev/mapper/controller--vg-root

#skrink root partition
resize2fs -p /dev/mapper/controller--vg-root 5G

#fsck disk
e2fsck -f /dev/mapper/controller--vg-root

#shrink logical volume
lvreduce -L -10G /dev/controller-vg/root

#create new logical volumes within appropriate group
lvcreate -L 1G -n var controller-vg 
lvcreate -L 1G -n log controller-vg 
lvcreate -L 1G -n audit controller-vg 
lvcreate -L 1G -n tmp controller-vg 
lvcreate -L 1G -n vartmp controller-vg 
lvcreate -L 1G -n home controller-vg 
lvcreate -L 1G -n mysql controller-vg 

#reboot into /dev/sda-b system
reboot NOW
