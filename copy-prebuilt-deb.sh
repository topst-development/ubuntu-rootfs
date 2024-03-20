# This script is used to copy prebuilt deb packages to the build directory.

# File list to copy is in prebuilt-deb/file.list

# temporary set dkkang's path
# [TODO] need to change to proper path
YOCTO_ROOT_DIR=/home/dkkang/build-autolinux/
AARCH64_DIR=${YOCTO_ROOT_DIR}/build/tcc8050-main/tmp/deploy/deb/aarch64/
TCC8050_MAIN_DIR=${YOCTO_ROOT_DIR}/build/tcc8050-main/tmp/deploy/deb/tcc8050_main/
TARGET_DIR=./prebuilt-deb

# copy prebuilt deb packages in file list
while read line
do
    echo "copying ${line}... to ${TARGET_DIR}"
    cp ${AARCH64_DIR}/${line} ${TARGET_DIR}
done < prebuilt-deb/aarch64.list

# copy prebuilt deb packages in file list
while read line
do
    echo "copying ${line} on TCC8050(main) to ${TARGET_DIR}"
    cp ${TCC8050_MAIN_DIR}/${line} ${TARGET_DIR}
done < prebuilt-deb/tcc8050_main.list
