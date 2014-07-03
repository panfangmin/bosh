#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash

cp $assets_dir/95-bosh-cdrom.rules $chroot/etc/udev/rules.d/95-bosh-cdrom.rules

install -m0755 $assets_dir/ready_cdrom.sh $chroot/etc/udev/rules.d/ready_cdrom.sh


# Disable cdrom lock when it is used, otherwise vsphere pops up questions in API
# This is not an issue on lucid
if [ "${stemcell_operating_system}" == "centos" ]; then
  echo "dev.cdrom.lock=0" >> $chroot/etc/sysctl.conf
elif [ "${stemcell_operating_system_version}" == "trusty" ]; then
  # Prevent trusty to lock cdrom in udev rules
  cp $assets_dir/60-cdrom_id.rules $chroot/etc/udev/rules.d/60-cdrom_id.rules
fi
