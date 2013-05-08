Puppet::Type.newtype(:quantum_network) do

  ensurable

  feature :provider_extension,
      "The provider supports provider networks."

  newparam(:name, :namevar => true) do
    desc 'Symbolic name for the network'
    newvalues(/.*/)
  end

  newproperty(:id) do
    desc 'The unique id of the network'
    validate do |v|
      raise(Puppet::Error, 'This is a read only property')
    end
  end

  newproperty(:admin_state_up) do
    desc 'The administrative status of the network'
    newvalues(/(t|T)rue/, /(f|F)alse/)
    defaultto('True')
    munge do |v|
      v.to_s.capitalize
    end
  end

  newproperty(:shared) do
    desc 'Whether this network should be shared across all tenants or not'
    newvalues(/(t|T)rue/, /(f|F)alse/)
    defaultto('False')
    munge do |v|
      v.to_s.capitalize
    end
  end

  newproperty(:tenant_id) do
    desc 'A uuid identifying the tenant which will own the network.'
  end

  newproperty(:provider_network_type, :required_features => :provider_extension) do
    desc 'The physical mechanism by which the virtual network is realized.'
    newvalues(:flat, :vlan, :local, :gre)
  end

  newproperty(:provider_physical_network, :required_features => :provider_extension) do
    desc <<-EOT
      The name of the physical network over which the virtual network
      is realized for flat and VLAN networks.
    EOT
    newvalues(/\S+/)
  end

  newproperty(:provider_segmentation_id, :required_features => :provider_extension) do
    desc 'Identifies an isolated segment on the physical network.'
    munge do |v|
      Integer(v)
    end
  end

  # Require the quantum-server service to be running
  autorequire(:service) do
    ['quantum-server']
  end

  validate do
    if self[:provider_network_type] || self[:provider_physical_network] || self[:provider_segmentation_id]
       if self[:provider_network_type].nil? || self[:provider_physical_network].nil? || self[:provider_segmentation_id].nil?
         raise(Puppet::Error, 'All provider properties are required when using provider extension.')
       end
    end
  end

end
