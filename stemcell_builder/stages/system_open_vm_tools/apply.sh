#!/usr/bin/env bash

set -e

base_dir=$(readlink -nf $(dirname $0)/../..)
source $base_dir/lib/prelude_apply.bash
source $base_dir/lib/prelude_bosh.bash

if [ ${OS_TYPE} == "ubuntu" ]
  pkg_mgr install open-vm-tools
else
  echo "No installation strategy for open-vm-tools, exiting..."
  exit 2
fi

