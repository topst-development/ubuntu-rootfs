#!/bin/sh
set -e

# get arguments
while [ $# -gt 0 ]; do
    case "$1" in
    --help)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --help              Display this help message"
        echo "  --arch=ARCH         Architecture (arm64, armhf, amd64, i386)"
        echo "  --release=RELEASE   Ubuntu release (focal, bionic, xenial)"
        echo "  --mirror=MIRROR     Ubuntu mirror"
        echo "  --apt-file=APT_FILE Apt source list file"
        echo "  --prebuilt-fstab=PREBUILT_FSTAB Prebuilt fstab file"
        echo "  --image-size=IMAGE_SIZE Image size (in bytes)"
        echo "  --image-name=IMAGE_NAME Image name"
        echo "  --launcher=LAUNCHER_NAME (default is weston)"
        exit 0
        ;;
    --arch=*)
        ARCH="${1#*=}"
        ;;
    --release=*)
        RELEASE="${1#*=}"
        ;;
    --mirror=*)
        MIRROR="${1#*=}"
        ;;
    --apt-file=*)
        APT_FILE="${1#*=}"
        ;;
    --prebuilt-fstab=*)
        PREBUILT_FSTAB="${1#*=}"
        ;;
    --use-prebuilt-rootfs)
        USE_PREBUILT_ROOTFS=1
        ;; 
    --image-size=*)
        IMAGE_SIZE="${1#*=}"
        ;;
    --image-name=*)
        IMAGE_NAME="${1#*=}"
        ;;
    --skip-deleterfs)
        SKIP_DELETERFS=1
        ;;
    --skip-bootstrap)
        SKIP_BOOTSTRAP=1
        ;;
    --skip-configure)
        SKIP_CONFIGURE=1
        ;;
    --skip-prebuilt-deb)
        SKIP_PREBUILT_DEB=1
        ;;
    --skip-prebuilt-fstab)
        SKIP_PREBUILT_FSTAB=1
        ;;
    --skip-image)
        SKIP_IMAGE=1
        ;;
    --launcher=*)
        LAUNCHER_NAME="${1#*=}"
        ;;
    *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
    shift
done

SKIP_MPTOOL=${SKIP_MPTOOL:-0}
SKIP_DELETERFS=${SKIP_DELETERFS:-0}
SKIP_BOOTSTRAP=${SKIP_BOOTSTRAP:-0}
SKIP_CONFIGURE=${SKIP_CONFIGURE:-0}
SKIP_PREBUILT_DEB=${SKIP_PREBUILT_DEB:-0}
SKIP_PREBUILT_FSTAB=${SKIP_PREBUILT_FSTAB:-0}
SKIP_IMAGE=${SKIP_IMAGE:-0}
LAUNCHER_NAME=${LAUNCHER_NAME:-weston}
COMPRESS_IMAGE=${COMPRESS_IMAGE:-0}

# Check if required packages are installed, and install them if needed
REQUIRED_PACKAGES="debootstrap qemu-user-static binfmt-support"

for package in $REQUIRED_PACKAGES; do
    if ! dpkg -s $package >/dev/null 2>&1; then
        echo "Installing $package..."
        sudo apt-get update
        sudo apt-get install -y $package
    fi
done

# Set default variables if not set
ARCH=${ARCH:-arm64}
# QEUMU_ARCH is the architecture used by qemu
if [ "$ARCH" = "arm64" ]; then
    QEMU_ARCH=aarch64
elif [ "$ARCH" = "armhf" ]; then
    QEMU_ARCH=arm
elif [ "$ARCH" = "amd64" ]; then
    QEMU_ARCH=x86_64
elif [ "$ARCH" = "i386" ]; then
    QEMU_ARCH=i386
else
    echo "Unknown architecture: $ARCH"
    exit 1
fi
RELEASE=${RELEASE:-jammy}
DEFAULT_MIRROR=http://ports.ubuntu.com/ubuntu-ports/
#DEFAULT_MIRROR=http://mirror.misakamikoto.network/ubuntu-ports/
if [ "$ARCH" = "arm64" ]; then
    MIRROR=${MIRROR:-$DEFAULT_MIRROR}
elif [ "$ARCH" = "armhf" ]; then
    MIRROR=${MIRROR:-$DEFAULT_MIRROR}
else
    echo "Unknown architecture: $ARCH"
    exit 1
fi

DATE_TIME=$(date "+%Y%m%d-%H%M")
APT_DIR=apt
#APT_FILE=${APT_FILE:-sources.list.misakamikoto.port}
APT_FILE=${APT_FILE:-sources.list.ubuntu.port}
BUILD_DIR=build
TARGET_DIR="${BUILD_DIR}/rootfs"
# For eMMC 8GB
IMAGE_SIZE=${IMAGE_SIZE:-6495928320}
# For eMMC 8GB - Single core
#IMAGE_SIZE=${IMAGE_SIZE:-7128219648}
# For eMMC 32GB
#IMAGE_SIZE=${IMAGE_SIZE:-28873588736}

IMAGE_NAME=${IMAGE_NAME:-ubuntu-${RELEASE}-${ARCH}-${DATE_TIME}.img}
PREBUILT_FSTAB="fstab/fstab.ubuntu-jammy-arm64"
PREBUILT_DEB="prebuilt-deb"
ROOTFS_NAME=rootfs.tar.gz
PREBUILT_ROOTFS_DIR="https://tost-dl.huconn.com/share/AP/ubuntu_rootfs"

# Download the prebuilt rootfs
if [ "$USE_PREBUILT_ROOTFS" = "1" ]; then
    sudo wget --no-check-certificate $PREBUILT_ROOTFS_DIR/$ROOTFS_NAME
fi

if [ -f $ROOTFS_NAME ]; then
    echo "Load the prebuilt rootfs"
    sudo rm -rf $TARGET_DIR/*
    sudo tar zxvf rootfs.tar.gz
else
    # Create the rootfs directory
    echo "Creating the rootfs directory"
    mkdir -p $TARGET_DIR

    # Run debootstrap to create the rootfs
    # if you want to use a proxy, add --http-proxy=http://proxy.example.com:port
    # to the debootstrap command
    # check if the rootfs directory is empty. If not, delete it
    if [ "$SKIP_DELETERFS" = "0" ]; then
        if [ "$(ls -A $TARGET_DIR)" ]; then
            echo "Deleting the rootfs directory"
            sudo rm -rf $TARGET_DIR/*
        fi
    fi

    if [ "$SKIP_BOOTSTRAP" = "0" ]; then
        # Run the first stage of debootstrap
        echo "Running debootstrap first stage"
        sudo debootstrap --arch $ARCH --foreign $RELEASE $TARGET_DIR $MIRROR
    fi

    # Copy the qemu-aarch64-static binary to the rootfs
    sudo cp /usr/bin/qemu-$QEMU_ARCH-static $TARGET_DIR/usr/bin/

    if [ "$SKIP_BOOTSTRAP" = "0" ]; then
        # Run the second stage of debootstrap
        echo "Running debootstrap second stage"
        sudo chroot $TARGET_DIR /debootstrap/debootstrap --second-stage
    fi

    if [ "$SKIP_CONFIGURE" = "0" ]; then
        # Configure the rootfs
        echo "Configuring the rootfs"
        # Add apt source list to the root filesystem
        sudo cp $APT_DIR/$APT_FILE $TARGET_DIR/etc/apt/sources.list

        # Configure the rootfs
        sudo chroot $TARGET_DIR /bin/sh -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"
        sudo chroot $TARGET_DIR /bin/sh -c "echo 'nameserver 8.8.4.4' >> /etc/resolv.conf"
        sudo chroot $TARGET_DIR /bin/sh -c "echo '$RELEASE' > /etc/hostname"
        sudo chroot $TARGET_DIR /bin/sh -c "echo '127.0.1.1    $RELEASE' >> /etc/hosts"

        # Configure the root password
        sudo chroot $TARGET_DIR /bin/sh -c "echo 'root:root' | chpasswd"

        # Add user named 'topst' and make them a sudoer
        sudo chroot $TARGET_DIR /bin/bash -c "useradd -m -G sudo -s /bin/bash topst"
        sudo chroot $TARGET_DIR /bin/bash -c "echo 'topst:topst' | chpasswd"

        # Install the openssh-server package
        sudo chroot $TARGET_DIR /bin/sh -c "apt-get update && apt-get install -y openssh-server"
    fi

    #if olny release is jammy, install the weston launcher
    if [ "$RELEASE" = "jammy" ]; then
        echo "Install Weston-Wayland"
        sudo cp application/install-weston.sh $TARGET_DIR/root
        sudo chroot $TARGET_DIR /bin/bash -c "/root/install-weston.sh"
        sudo rm -rf $TARGET_DIR/root/install-weston.sh
        sudo cp application/TOPST-background.png $TARGET_DIR/usr/share/weston/
    fi

    #if olny release is focal, install the weston launcher
    if [ "$RELEASE" = "focal" ]; then
        echo "Install xubuntu-desktop"
        sudo cp application/install-xubuntu-desktop.sh $TARGET_DIR/root
        sudo chroot $TARGET_DIR /bin/bash -c "/root/install-xubuntu-desktop.sh"
        sudo rm -rf $TARGET_DIR/root/install-xubuntu-desktop.sh
    fi

    echo "backup the rootfs directory"
    sudo tar -zcvf rootfs.tar.gz $TARGET_DIR/*
fi

# Install WiFi Tool for USB-MT7601U
if [ "$ADD_WIFI_TOOL" = "1" ]; then
#    sudo chroot $TARGET_DIR /bin/sh -c "apt --fix-broken install -y"
    sudo chroot $TARGET_DIR /bin/sh -c "apt-get update && apt-get install -y --reinstall linux-firmware"
    sudo chroot $TARGET_DIR /bin/sh -c "apt-get install -y wpasupplicant"
    sudo chroot $TARGET_DIR /bin/sh -c "apt-get install -y  iw"
    sudo chroot $TARGET_DIR /bin/sh -c "cat > /etc/wpa_supplicant/HUCONN_2.4.conf <<EOF
ctrl_interface=/var/run/wpa_supplicant
ctrl_interface_group=0
update_config=1
network={
ssid=\"HUCONN_2.4G\"
#scan_ssid=1
psk=\"123456789\"
key_mgmt=WPA-PSK
proto=RSN
pairwise=CCMP
group=CCMP
}
EOF"
fi

# Install additional packages from .deb files
sudo mount -t tmpfs tmpfs $TARGET_DIR/tmp

if [ "$SKIP_PREBUILT_DEB" = "0" ]; then
    echo "Install prebuilted packages from .deb files"
    #sudo cp "$PREBUILT_DEB"/*.deb "$TARGET_DIR/tmp/"

    # Install the prebuilted package
    export LC_ALL=C
    package_files="prebuilt-deb/aarch64.list prebuilt-deb/tcc8050_main.list"

    for file in $package_files
    do
        while IFS= read -r deb_file
        do
            package_name="${deb_file%%"_"*}"

            if [ -e $PREBUILT_DEB/$deb_file ]; then
                sudo cp $PREBUILT_DEB/$deb_file $TARGET_DIR/tmp/

                if sudo chroot "$TARGET_DIR" /bin/bash -c "dpkg -s "$package_name" >/dev/null 2>&1"; then
                    echo "Package '$package_name' is already installed."
                else
                   # sudo chroot "$TARGET_DIR" /bin/bash -c "dpkg -i --force-all /tmp/$deb_file"
                    if sudo chroot "$TARGET_DIR" /bin/bash -c "dpkg -i --force-depends --force-bad-version --no-triggers /tmp/$deb_file"; then
                        echo "Package '$package_name' installed successfully."
                    else
                        echo "Error installing package '$package_name'. Continuing with the next package..."
                        continue
                    fi
                fi
            else
                echo "[WORN] $PREBUILT_DEB/$deb_file is not exists !!"
            fi
        done < "$file"
    done

    # Exception : Happend the module is removed by dependency checking when apt update.
    sudo chroot "$TARGET_DIR" /bin/sh -c "sed -i 's/^Depends: kernel-5.4.159-tcc/#Depends: kernel-5.4.159-tcc/g'  /var/lib/dpkg/status"
    sudo chroot "$TARGET_DIR" /bin/sh -c "sed -i 's/^Depends: libc6 (>= 2.31+git0+3ef8be9b89), libpvr-telechips (>= 1.15)/#Depends: libc6 (>= 2.31+git0+3ef8be9b89), libpvr-telechips (>= 1.15)/g'  /var/lib/dpkg/status"
    sudo chroot "$TARGET_DIR" /bin/sh -c "sed -i 's/^Depends: libc6 (>= 2.31+git0+3ef8be9b89), libdrm (>= 2.4.100)/#Depends: libc6 (>= 2.31+git0+3ef8be9b89), libdrm (>= 2.4.100)/g'  /var/lib/dpkg/status"

    # systemd modules-load
    sudo cp $PREBUILT_DEB/etc/modules-load.d/* $TARGET_DIR/etc/modules-load.d/

    # install-wifi-ax3000 
    #sudo application/install-wifi-ax3000.sh $TARGET_DIR
fi

# Enable root login via ssh
sudo chroot $TARGET_DIR /bin/sh -c "sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"

# Install fstab from prebuilt
if [ -f $PREBUILT_FSTAB ]; then
    sudo cp $PREBUILT_FSTAB $TARGET_DIR/etc/fstab
fi

# Configure the apt sources
#sudo chroot $TARGET_DIR /bin/sh -c "sed -i 's/archive.ubuntu.com/mirror.misakamikoto.network/g' /etc/apt/sources.list"

## Configure MAC Address
echo "Configuring the network"
sudo cat > rc.local << EOF
#!/bin/sh

interface="eth0"
initial_mac="f4:8c:09:b1:19:82"
vendor_mac="cc:7a:30:"
prefix_mac=\$(grep -oP '(?<=TOPST_MAC_ADDRESS=")[^"]*' /etc/environment)

if [ -z "\$prefix_mac" ] ; then
    desired_mac=\$(openssl rand -hex 3 | sed 's/\(..\)/\1:/g; s/.$//')
    echo "Changing MAC address: \$vendor_mac\$desired_mac"

    ip link set dev \$interface down
    ip link set dev \$interface address \$vendor_mac\$desired_mac
    ip link set dev \$interface up

    new_mac=\$(cat /sys/class/net/\$interface/address)

    if [ "\$new_mac" = "\$vendor_mac\$desired_mac" ]; then
        echo "TOPST_MAC_ADDRESS=\"\$vendor_mac\$desired_mac\"" >> /etc/environment
        echo "MAC address successfully updated."
    else
        echo "Failed to update MAC address."
    fi

    # Install the prebuilt package
    package_files="/root/boot-package.list"
    if [ -e "\$package_files" ]; then
        for file in \$package_files
        do
            while IFS= read -r deb_file
            do
                package_name="\${deb_file%%"_"*}"
                if [ -e /root/\$deb_file ]; then
                    if dpkg -s "\$package_name" >/dev/null 2>&1; then
                        echo "Package '\$package_name' is already installed."
                    else
                        echo "Install /root/\$deb_file"
                        dpkg -i --force-depends --force-bad-version /root/\$deb_file
                    fi
                else
                    echo "[WORN] /root/\$deb_file is not exists !!"
                fi
            done < "\$file"
        done
        rm -rf \$package_files
    fi
else
    ip link set dev \$interface down
    ip link set dev \$interface address \$prefix_mac
    ip link set dev \$interface up
fi
EOF

sudo mv rc.local $TARGET_DIR/etc/rc.local
sudo chroot $TARGET_DIR /bin/sh -c "chmod +x /etc/rc.local"
sudo chroot $TARGET_DIR /bin/sh -c "cat >> /lib/systemd/system/rc-local.service << EOF

[Install]
WantedBy=multi-user.target
EOF"
sudo chroot $TARGET_DIR /bin/sh -c "systemctl enable rc-local.service"

# Install the prebuilted package
package_files="$PREBUILT_DEB/boot-package.list"
for file in $package_files
do
    while IFS= read -r deb_file
    do
        if [ -e $PREBUILT_DEB/$deb_file ]; then
            sudo cp $PREBUILT_DEB/$deb_file $TARGET_DIR/root
        else
            echo "[WORN] $PREBUILT_DEB/$deb_file is not exists !!"
        fi
    done < "$file"
done
sudo cp $PREBUILT_DEB/boot-package.list $TARGET_DIR/root/

## Configure Netplan
NETPLAN_CONFIG="99-default.yaml"
NETPLAN_DIR="/etc/netplan"
sudo chroot $TARGET_DIR /bin/sh -c "cat > $NETPLAN_DIR/$NETPLAN_CONFIG << EOF
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true
      optional: true
EOF"

# Install MP Tool
if [ "$SKIP_MPTOOL" = "1" ]; then
    echo "Install MP Tools"
    sudo cp application/topst_test_main.service $TARGET_DIR/lib/systemd/system/
    sudo chroot $TARGET_DIR /bin/sh -c "chmod 644 /lib/systemd/system/topst_test_main.service"

    # MP Tool start service 
    sudo chroot $TARGET_DIR /bin/bash -c "systemctl enable topst_test_main"

    # Install USB automount
    sudo cp application/usb-automount.sh $TARGET_DIR/root
    sudo chroot $TARGET_DIR /bin/bash -c "/root/usb-automount.sh"
    sudo rm -rf $TARGET_DIR/root/usb-automount.sh
fi

# modify systemd-udevd.service file for automount
sudo sed -i '/PrivateMounts/,/$p/ s/^/#/g' $TARGET_DIR/usr/lib/systemd/system/systemd-udevd.service

# Cleanup the rootfs
sudo rm $TARGET_DIR/usr/bin/qemu-$QEMU_ARCH-static

# Unmount the image
sudo umount "$TARGET_DIR/tmp"

echo "Ubuntu $RELEASE $ARCH rootfs is ready at $TARGET_DIR"

# Create the ext4 image
echo "Creating $IMAGE_NAME with size $IMAGE_SIZE bytes"
dd if=/dev/zero of=$IMAGE_NAME bs=1 count=0 seek=$IMAGE_SIZE
sudo mkfs.ext4 -F $IMAGE_NAME

# Mount the image and copy the rootfs
echo "Mounting the image and copying the rootfs"
MOUNT_DIR=$(mktemp -d)
sudo mount -o loop $IMAGE_NAME $MOUNT_DIR
sudo cp -a $TARGET_DIR/* $MOUNT_DIR

# Unmount the image
sudo umount $MOUNT_DIR
rm -rf $MOUNT_DIR

echo "The ext4 image $IMAGE_NAME containing the rootfs is ready"

# Compress the image
if [ "$COMPRESS_IMAGE" = "1" ]; then
    echo "Compressing the image"
    xz -T 0 -k -v $IMAGE_NAME
fi

# link the image for fwdn
ln -sf "$(pwd)/$IMAGE_NAME" fwdn/deploy-images/$IMAGE_NAME

# create FWDN Script for fwdn/fwdn-ubuntu.sh
sudo cat > fwdn/fwdn-ubuntu.bat << EOF
@echo off

echo Start the FWDN V8 for ubuntu image

if exist %deploy-images\boot-firmware (
    echo Connect FWDN V8 to Board
    fwdn.exe --fwdn deploy-images\boot-firmware\fwdn.json

    echo Ubuntu File System install for main core
    if exist %deploy-images\\$IMAGE_NAME (
        fwdn.exe -w deploy-images\\$IMAGE_NAME --storage emmc --area user --part system
    ) else (
        echo Not exist $IMAGE_NAME
    )

    echo End !!
    exit /b
) else (
    echo Not exist boot-fimware file
)
EOF

sudo cat > fwdn/fwdn-ubuntu.sh << EOF
#!/bin/bash

echo "Start the FWDN V8 for ubuntu image"

main_path="deploy-images/tcc8050-main"
sub_path="deploy-images/tcc8050-sub"

echo -e "\nVerify that Usb is connected"

DEVICE_ID="140e:b201 Telechips, Inc."
USB_LIST=\$(lsusb)

if ! echo "\$USB_LIST" | grep -q "\$DEVICE_ID"; then
    echo "Not found device of \$DEVICE_ID"
    exit 1
fi 

echo -e "\nConnect FWDN V8 to Board"
sudo ./fwdn --fwdn deploy-images/boot-firmware/fwdn.json

echo -e "\nUbuntu File System install for main core\n"
sudo ./fwdn -w deploy-images/$IMAGE_NAME --storage emmc --area user --part system
EOF
