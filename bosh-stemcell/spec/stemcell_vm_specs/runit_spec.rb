require 'stemcell_vm_spec_helper'

describe package('runit') do
  it { should be_installed }
end

describe service('runsvdir') do
  it { should be_enabled } 
  it { should be_running }
end
