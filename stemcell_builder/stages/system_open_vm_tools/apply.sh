#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

if [ ${OS_TYPE} == "ubuntu" ]
then
  if [ "${DISTRIB_CODENAME}" == "lucid" ]
  then
    mkdir -p $chroot/tmp
    cp $assets_dir/vmware-tools-repo-ubuntu10.04_9.4.5-1.lucid_amd64.deb $chroot/tmp/

    run_in_chroot $chroot "
      dpkg -i vmware-tools-repo-ubuntu10.04_9.4.5-1.lucid_amd64.deb
      apt-get update
      apt-get install -y vmware-open-vm-tools-kmod-source vmware-tools-vmci-modules vmware-tools-vmxnet3-modules-source debhelper module-assistant

      module-assistant prepare

      kernel_source_dir=$(ls /usr/src/linux-headers-3*.virtual | tail -1)

      module-assistant build vmware-open-vm-tools-kmod-source vmware-tools-vmci-modules vmware-tools-vmxnet3-modules-source -v -t -k $kernel_source_dir
      module-assistant install vmware-open-vm-tools-kmod vmware-tools-vmxnet3-modules-source

      apt-get install vmware-open-vm-tools-nox
    "

    rm $chroot/tmp/*.deb
  elif [ "${DISTRIB_CODENAME}" == "trusty" ]
  then
    pkg_mgr install open-vm-tools
  fi
else
  echo "No installation strategy for open-vm-tools, exiting..."
  exit 2
fi

