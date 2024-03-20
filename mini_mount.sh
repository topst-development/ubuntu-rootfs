#!/bin/sh
set -e

TARGET_DIR="build/rootfs"
# image size is 5GB
IMAGE_SIZE=${IMAGE_SIZE:-5368709120}
IMAGE_NAME=${IMAGE_NAME:-ubuntu.img}

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