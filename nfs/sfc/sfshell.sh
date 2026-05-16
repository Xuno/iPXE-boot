#!/usr/bin/bash

cd ./sfc_extract/

sudo mount --bind /dev ./dev
sudo mount --bind /proc ./proc
sudo mount --bind /sys ./sys

echo GOING to CHROOT BASH SHELL, ctrl-D or exit will back to real OS.
echo for upgade use : sfupdate --wtite
echo for set boot image use : sfboot boot-image=all


sudo chroot . /bin/bash

echo BACK from CHROOT
sudo umount ./dev
sudo umount ./proc
sudo umount ./sys
