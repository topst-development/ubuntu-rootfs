#!/bin/sh

cat >/etc/udev/rules.d/99-usb-mount.rules <<EOF
# skip emmc partition
ENV{DEVNAME}=="/dev/mmcblk0*",         GOTO="skip_automount"
ENV{DEVNAME}=="/dev/mmcblk0boot0",      GOTO="skip_automount"
ENV{DEVNAME}=="/dev/mmcblk0boot1",      GOTO="skip_automount"
ENV{DEVNAME}=="/dev/mmcblk0rpmb",      GOTO="skip_automount"

SUBSYSTEM=="block", ACTION=="add", ENV{SYSTEMD_WANTS}+="usb-mount@%k.service"

LABEL="skip_automount"
EOF

cat >/etc/systemd/system/usb-mount@.service <<EOF
[Unit]
Description=USB Mount (%I)
Requires=local-fs.target
After=local-fs.target

[Service]
Type=oneshot
ExecStartPre=/bin/mkdir -p /run/media/%I
ExecStart=/bin/mount /dev/%I /run/media/%I

[Install]
WantedBy=multi-user.target
EOF