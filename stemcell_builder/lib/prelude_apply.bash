source $base_dir/lib/prelude_common.bash
source $base_dir/lib/helpers.sh

work=$1
chroot=${chroot:=$work/chroot}
mkdir -p $work $chroot

# Source settings if present
if [ -f $settings_file ]
then
  source $settings_file
fi

# Source /etc/lsb-release if present
if [ -f $chroot/etc/lsb-release ]
then
  source $chroot/etc/lsb-release
fi

function os_type {
  CENTOS_FILE=$chroot/etc/centos-release
  UBUNTU_FILE=$chroot/etc/debian_version

  if [ -f $UBUNTU_FILE ]
  then
    echo ubuntu
  elif [ -f $CENTOS_FILE ]
  then
    echo centos
  fi
}

function pkg_mgr {
  os_type=`os_type`
  if [ $os_type = 'ubuntu' ]
  then
    run_in_chroot $chroot "apt-get update"
    run_in_chroot $chroot "apt-get -f -y --force-yes --no-install-recommends $*"
    run_in_chroot $chroot "apt-get clean"
  elif [ $os_type -eq 'centos' ]
  then
    run_in_chroot $chroot "yum update --assumeyes"
    run_in_chroot $chroot "yum --verbose --assumeyes $*"
    run_in_chroot $chroot "yum clean all"
  else
    echo "Unknown OS, exiting"
    exit 2
  fi
}
