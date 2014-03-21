require 'stemcell_vm_spec_helper'

# We have to force serverspec to use a login shell
describe command('bash -l -c "go version"') do
  its(:stdout) { should match /go version go1.2/ }
end

describe file('/home/ubuntu/.profile') do
  it { should contain 'source $HOME/.gvm/scripts/gvm' }
end
