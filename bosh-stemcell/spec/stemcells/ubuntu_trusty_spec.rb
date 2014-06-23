require 'spec_helper'

describe 'Ubuntu 14.04 stemcell', stemcell_image: true do
  context 'installed by image_install_grub', exclude_on_warden: true do
    describe file('/boot/grub/grub.cfg') do
      it { should be_file }
      it { should contain "menuentry 'Ubuntu' --class ubuntu --class gnu-linux --class gnu --class os $menuentry_id_option 'gnulinux-simple-/dev/sda1' {" }
      it { should contain %r{linux   /boot/vmlinuz-\S+-generic root=LABEL=cloudimg-rootfs ro   console=tty1 console=ttyS0} }
      it { should contain %r{initrd  /boot/initrd.img-\S+-generic} }
    end

    describe file('/etc/default/grub') do
      it { should be_file }
      it { should contain 'GRUB_CMDLINE_LINUX="cgroup_enable=memory selinux=0"' }
    end

    describe file('/boot/grub/menu.lst') do
      before { skip 'until aws/openstack stop clobbering the symlink with "update-grub"' }
      it { should be_linked_to('./grub.conf') }
    end
  end

  context 'installed by system_parameters' do
    describe file('/var/vcap/bosh/etc/operating_system') do
      it { should contain('ubuntu') }
    end
  end

  context 'installed by bosh_harden' do
    describe 'disallow unsafe setuid binaries' do
      subject { backend.run_command('find -L / -xdev -perm +6000 -a -type f')[:stdout].split }

      it { should match_array(%w(/bin/su /usr/bin/sudo /usr/bin/sudoedit)) }
    end

    describe 'disallow root login' do
      subject { file('/etc/ssh/sshd_config') }

      it { should contain /^PermitRootLogin no$/ }
    end
  end

  context 'installed by system-aws-network', {
    exclude_on_vsphere: true,
    exclude_on_vcloud: true,
    exclude_on_warden: true,
  } do
    describe file('/etc/network/interfaces') do
      it { should be_file }
      it { should contain 'auto eth0' }
      it { should contain 'iface eth0 inet dhcp' }
    end
  end
end
