#!/bin/bash

export LC_ALL=C
TARGET_DIR="$1"
package_files="kernel-module-iwlwifi-5.4.159-tcc_5.4.159-r0_arm64.deb
kernel-module-iwldvm-5.4.159-tcc_5.4.159-r0_arm64.deb
kernel-module-iwlmvm-5.4.159-tcc_5.4.159-r0_arm64.deb"

for deb_file in $package_files
do
    package_name="${deb_file%%"_"*}"
    if sudo chroot "$TARGET_DIR" /bin/bash -c "dpkg -s "$package_name" >/dev/null 2>&1"; then
        echo "Package '$package_name' is already installed."
    else
      sudo cp prebuilt-deb/$deb_file $TARGET_DIR/tmp/
      sudo chroot "$TARGET_DIR" /bin/bash -c "dpkg -i --force-depends --force-bad-version /tmp/$deb_file"
      #sudo chroot "$TARGET_DIR" /bin/bash -c "dpkg --set-selections < /tmp/selections"
    fi
done

# Exception : Happend the module is removed by dependency checking when apt update.
sudo chroot "$TARGET_DIR" /bin/sh -c "sed -i 's/^Depends: kernel-5.4.159-tcc/#Depends: kernel-5.4.159-tcc/g'  /var/lib/dpkg/status"
sudo chroot "$TARGET_DIR" /bin/sh -c "sed -i 's/^Depends: libc6 (>= 2.31+git0+3ef8be9b89), libpvr-telechips (>= 1.15)/#Depends: libc6 (>= 2.31+git0+3ef8be9b89), libpvr-telechips (>= 1.15)/g'  /var/lib/dpkg/status"
sudo chroot "$TARGET_DIR" /bin/sh -c "sed -i 's/^Depends: libc6 (>= 2.31+git0+3ef8be9b89), libdrm (>= 2.4.100)/#Depends: libc6 (>= 2.31+git0+3ef8be9b89), libdrm (>= 2.4.100)/g'  /var/lib/dpkg/status"


sudo cp application/iwlwifi-cc-46.3cfab8da.0.tgz $TARGET_DIR/tmp/
sudo chroot "$TARGET_DIR" /bin/sh -c "tar zxvf /tmp/iwlwifi-cc-46.3cfab8da.0.tgz --strip-components=1 -C /lib/firmware/"