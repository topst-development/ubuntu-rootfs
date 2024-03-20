# This script is used to create prebuilt selection file.

# find prebuilt deb packages in the directory
# and create prebuilt selection file
# prebuilt selection file is used to create prebuilt rootfs
# make file list
find ./prebuilt-deb -name "*.deb" > /tmp/prebuilt-deb.list
# get package name from file list
# and create prebuilt selection file
while read line
do
    dpkg -I ${line} | grep Package: | awk '{print $2}' >> /tmp/prebuilt-deb-selection.list
    echo "${line}"
done < /tmp/prebuilt-deb.list
