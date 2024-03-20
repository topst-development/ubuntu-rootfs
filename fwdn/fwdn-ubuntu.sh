#!/bin/bash

echo Start the FWDN V8 for ubuntu image"

main_path="deploy-images/tcc8050-main"
sub_path="deploy-images/tcc8050-sub"

echo -e "\nVerify that Usb is connected"

DEVICE_ID="140e:b201 Telechips, Inc."
USB_LIST=$(lsusb)

if ! echo "$USB_LIST" | grep -q "$DEVICE_ID"; then
	echo "Not found device of $DEVICE_ID"
	exit 1
fi 

echo -e "\nConnect FWDN V8 to Board"
sudo ./fwdn --fwdn deploy-images/boot-firmware/fwdn.json

echo -e "\nUbuntu File System install for main core\n"
sudo ./fwdn -w deploy-images/automotive-linux-platform-image-tcc8050-main.ext4 --storage emmc --area user --part system