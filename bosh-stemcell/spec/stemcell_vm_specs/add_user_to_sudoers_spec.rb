require 'stemcell_vm_spec_helper'

describe user('ubuntu') do
  it { should belong_to_group 'sudo' }
end
