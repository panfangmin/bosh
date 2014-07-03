require File.expand_path('../../../spec_helper', __FILE__)

describe Bosh::Director::DeploymentPlan::ResourcePool do
  subject(:resource_pool) { BD::DeploymentPlan::ResourcePool.new(plan, valid_spec, logger) }
  let(:logger) { Logger.new('/dev/null') }
  let(:max_size) { 2 }

  let(:valid_spec) do
    {
      'name' => 'small',
      'size' => max_size,
      'network' => 'test',
      'stemcell' => {
        'name' => 'stemcell-name',
        'version' => '0.5.2'
      },
      'cloud_properties' => { 'foo' => 'bar' },
      'env' => { 'key' => 'value' },
    }
  end

  let(:network) { instance_double('Bosh::Director::DeploymentPlan::Network') }
  let(:plan) { instance_double('Bosh::Director::DeploymentPlan::Planner') }

  before { allow(plan).to receive(:network).with('test').and_return(network) }

  describe 'creating' do
    it 'parses name, size, stemcell spec, cloud properties, env' do
      expect(resource_pool.name).to eq('small')
      expect(resource_pool.size).to eq(max_size)
      expect(resource_pool.stemcell).to be_kind_of(BD::DeploymentPlan::Stemcell)
      expect(resource_pool.stemcell.name).to eq('stemcell-name')
      expect(resource_pool.stemcell.version).to eq('0.5.2')
      expect(resource_pool.network).to eq(network)
      expect(resource_pool.cloud_properties).to eq({ 'foo' => 'bar' })
      expect(resource_pool.env).to eq({ 'key' => 'value' })
    end

    %w(name cloud_properties).each do |key|
      context "when #{key} is missing" do
        before { valid_spec.delete(key) }

        it 'raises an error' do
          expect { BD::DeploymentPlan::ResourcePool.new(plan, valid_spec, logger) }.to raise_error(BD::ValidationMissingField)
        end
      end
    end

    %w(size).each do |key|
      context "when #{key} is missing" do
        before { valid_spec.delete(key) }

        it 'does not raise an error' do
          expect { BD::DeploymentPlan::ResourcePool.new(plan, valid_spec, logger) }.to_not raise_error
        end
      end
    end

    context 'when the deployment plan does not have the resource pool network' do
      before do
        valid_spec.merge!('network' => 'foobar')
        allow(plan).to receive(:network).with('foobar').and_return(nil)
      end

      it 'raises an error' do
        expect { BD::DeploymentPlan::ResourcePool.new(plan, valid_spec, logger) }.to raise_error(BD::ResourcePoolUnknownNetwork)
      end
    end

    context 'when the resource pool spec has no env' do
      before { valid_spec.delete('env') }

      it 'has default env' do
        expect(resource_pool.env).to eq({})
      end
    end
  end

  it 'returns resource pool spec as Hash' do
    expect(resource_pool.spec).to eq({
      'name' => 'small',
      'cloud_properties' => { 'foo' => 'bar' },
      'stemcell' => { 'name' => 'stemcell-name', 'version' => '0.5.2' }
    })
  end

  describe '#process_idle_vms' do
    before { allow(network).to receive(:reserve!) }

    context 'when resource pool has a fixed size' do
      it 'adds idle VMs up to the size' do
        resource_pool.process_idle_vms
        expect(resource_pool.idle_vms.size).to eq(max_size)
      end

      context 'when some VMs are already allocated' do
        before do
          resource_pool.add_idle_vm
          resource_pool.allocate_vm
        end

        it 'creates idle vm objects for missing idle VMs' do
          resource_pool.process_idle_vms
          expect(resource_pool.idle_vms.size).to eq(max_size - 1) # 1 is active
        end
      end

      context 'when some VMs are already idle' do
        let(:max_size) { 4 }

        before { resource_pool.add_idle_vm }

        it 'adds idle VMs up to the size' do
          resource_pool.process_idle_vms
          expect(resource_pool.idle_vms.size).to eq(max_size)
        end
      end

      context 'when some VMs are already idle and others are active' do
        let(:max_size) { 4 }

        before do
          resource_pool.add_idle_vm
          resource_pool.add_idle_vm
          resource_pool.allocate_vm
        end

        it 'creates idle vm objects for missing idle VMs' do
          resource_pool.process_idle_vms
          expect(resource_pool.idle_vms.size).to eq(max_size - 1) # 1 is active
        end
      end

      it 'reserves dynamic networks for idle VMs that do not have reservations' do
        expect(network).to receive(:reserve!).
          with(an_instance_of(BD::NetworkReservation), "Resource pool `small'").
          exactly(max_size).times

        resource_pool.process_idle_vms

        expect(resource_pool.idle_vms.select { |vm| vm.has_network_reservation? }.size).to eq(max_size)
      end

      it 'does not reserve dynamic networks for idle VMs that already have reservations' do
        max_size.times do
          idle_vm = resource_pool.add_idle_vm
          idle_vm.use_reservation(BD::NetworkReservation.new_dynamic)
        end

        expect(resource_pool.idle_vms.all? { |vm| vm.has_network_reservation? }).to eq(true)

        expect(network).to_not receive(:reserve!).
          with(an_instance_of(BD::NetworkReservation), "Resource pool `small'")

        resource_pool.process_idle_vms
      end
    end

    context 'when resource pool is dynamically sized' do
      before { valid_spec.delete('size') }

      it 'does not add any idle VMs' do
        resource_pool.process_idle_vms
        expect(resource_pool.idle_vms).to eq([])
      end

      it 'reserves dynamic networks for idle VMs that do not have reservations' do
        max_size.times { resource_pool.add_idle_vm }

        expect(network).to receive(:reserve!).
                             with(an_instance_of(BD::NetworkReservation), "Resource pool `small'").
                             exactly(max_size).times

        resource_pool.process_idle_vms

        expect(resource_pool.idle_vms.select { |vm| vm.has_network_reservation? }.size).to eq(max_size)
      end

      it 'does not reserve dynamic networks for idle VMs that already have reservations' do
        max_size.times do
          idle_vm = resource_pool.add_idle_vm
          idle_vm.use_reservation(BD::NetworkReservation.new_dynamic)
        end

        expect(resource_pool.idle_vms.all? { |vm| vm.has_network_reservation? }).to eq(true)

        expect(network).to_not receive(:reserve!).
                                 with(an_instance_of(BD::NetworkReservation), "Resource pool `small'")

        resource_pool.process_idle_vms
      end
    end
  end

  describe '#reserve_capacity' do
    it 'reserves capacity' do
      resource_pool.reserve_capacity(1)

      expect(resource_pool.reserved_capacity).to eq(1)
    end

    context 'when no additional capacity is availible' do
      before { resource_pool.reserve_capacity(max_size) }

      it 'raises an error and does not reserve capacity' do
        expect { resource_pool.reserve_capacity(1) }.to raise_error(BD::ResourcePoolNotEnoughCapacity)

        expect(resource_pool.reserved_capacity).to eq(max_size)
      end
    end

    context 'when capacity has already been reserved' do
      let(:max_size) { 4 }
      before { resource_pool.reserve_capacity(2) }

      it 'reserves more capacity' do
        resource_pool.reserve_capacity(1)

        expect(resource_pool.reserved_capacity).to eq(3)
      end
    end
  end

  describe '#reserve_errand_capacity' do
    context 'when resource pool has a fixed size' do
      it 'reserves errand capacity from the total capacity' do
        resource_pool.reserve_errand_capacity(1)

        expect(resource_pool.reserved_capacity).to eq(1)
      end

      context 'when no additional capacity is availible' do
        before { resource_pool.reserve_capacity(max_size) }

        it 'raises an error' do
          expect { resource_pool.reserve_errand_capacity(1) }.to raise_error(BD::ResourcePoolNotEnoughCapacity)

          expect(resource_pool.reserved_capacity).to eq(max_size)
        end
      end

      context 'when errand capacity has already been reserved' do
        let(:max_size) { 4 }
        before { resource_pool.reserve_errand_capacity(2) }

        it 'reserves more errand capacity, when more is requested' do
          resource_pool.reserve_errand_capacity(3)

          expect(resource_pool.reserved_capacity).to eq(3)
        end

        it 'does not reserve more errand capacity, when the same amount is requested' do
          resource_pool.reserve_errand_capacity(2)

          expect(resource_pool.reserved_capacity).to eq(2)
        end

        it 'does not reserve more errand capacity, when less is requested' do
          resource_pool.reserve_errand_capacity(1)

          expect(resource_pool.reserved_capacity).to eq(2)
        end
      end
    end

    context 'when resource pool is dynamically sized' do
      before { valid_spec.delete('size') }

      it 'reserves more errand capacity, when more is requested' do
        resource_pool.reserve_errand_capacity(3)

        expect(resource_pool.reserved_capacity).to eq(3)
      end
    end
  end

  describe '#allocate_vm' do
    context 'when resource pool has a fixed size' do
      context 'when the pool contains an idle VM' do
        before { resource_pool.add_idle_vm }

        it 'moves vm from idle to allocated vms' do
          allocated_vm = resource_pool.allocate_vm
          allocated_vm.model = instance_double('Bosh::Director::Models::Vm', cid: 'abc')

          expect(resource_pool.allocated_vms).to eq([allocated_vm])
          expect(resource_pool.idle_vms).to eq([])
        end
      end

      context 'when the pool does not contain any idle VMs' do
        it 'raises an error' do
          expect{
            resource_pool.allocate_vm
          }.to raise_error(
            Bosh::Director::ResourcePoolNotEnoughCapacity,
            /Resource pool `small' has no more VMs to allocate/,
          )
        end
      end
    end

    context 'when resource pool is dynamically sized' do
      before { valid_spec.delete('size') }

      context 'when the pool contains an idle VM' do
        before { resource_pool.add_idle_vm }

        it 'moves vm from idle to allocated vms' do
          allocated_vm = resource_pool.allocate_vm
          allocated_vm.model = instance_double('Bosh::Director::Models::Vm', cid: 'abc')

          expect(resource_pool.allocated_vms).to eq([allocated_vm])
          expect(resource_pool.idle_vms).to eq([])
        end
      end

      context 'when the pool does not contain any idle VMs' do
        it 'creates a new vm if dynamically sized and the idle pool is empty' do
          allocated_vm = resource_pool.allocate_vm
          allocated_vm.model = instance_double('Bosh::Director::Models::Vm', cid: 'abc')

          expect(resource_pool.allocated_vms).to eq([allocated_vm])
          expect(resource_pool.idle_vms).to eq([])
        end
      end
    end
  end

  describe '#deallocate_vm' do
    context 'when resource pool has a fixed size' do
      context 'when the pool contains an allocated vm' do
        let(:vm_model) { instance_double('Bosh::Director::Models::Vm', cid: 'abc') }

        before do
          resource_pool.add_idle_vm
          @allocated_vm = resource_pool.allocate_vm
          @allocated_vm.model = vm_model
        end

        it 'removes vm from allocated list and adds a new idle vm' do
          resource_pool.deallocate_vm(vm_model.cid)
          expect(resource_pool.allocated_vms).to be_empty
          expect(resource_pool.idle_vms.size).to eq(1)
          expect(resource_pool.idle_vms[0]).to_not eq(@allocated_vm)
          expect(resource_pool.idle_vms[0]).to be_an_instance_of(Bosh::Director::DeploymentPlan::Vm)
        end
      end

      context 'when the pool does not contain any allocated vms' do
        it 'raises an error' do
          expect{
            resource_pool.deallocate_vm('abc')
          }.to raise_error(
            Bosh::Director::DirectorError,
            /Resource pool `small' does not contain an allocated VM with the cid `abc'/,
          )
        end
      end
    end

    context 'when resource pool is dynamically sized' do
      before { valid_spec.delete('size') }

      context 'when the pool contains an allocated vm' do
        let(:vm_model) { instance_double('Bosh::Director::Models::Vm', cid: 'abc') }

        before do
          resource_pool.add_idle_vm
          @allocated_vm = resource_pool.allocate_vm
          @allocated_vm.model = vm_model
        end

        it 'removes vm from allocated and does not add it to idle vms' do
          resource_pool.deallocate_vm(vm_model.cid)
          expect(resource_pool.allocated_vms).to be_empty
          expect(resource_pool.idle_vms).to be_empty
        end
      end

      context 'when the pool does not contain any allocated vms' do
        it 'raises an error' do
          expect{
            resource_pool.deallocate_vm('abc')
          }.to raise_error(
            Bosh::Director::DirectorError,
            /Resource pool `small' does not contain an allocated VM with the cid `abc'/,
          )
        end
      end
    end
  end
end
