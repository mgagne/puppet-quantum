require File.join(File.dirname(__FILE__), '..','..','..', 'puppet/provider/quantum')

Puppet::Type.type(:quantum_network).provide(
  :quantum,
  :parent => Puppet::Provider::Quantum
) do
  desc <<-EOT
    Quantum provider to manage quantum_network type.

    Assumes that the quantum service is configured on the same host.
  EOT

  commands :quantum => 'quantum'

  mk_resource_methods

  def self.has_provider_extension?
    list_quantum_extensions.include?('provider')
  end

  def has_provider_extension?
    self.class.has_provider_extension?
  end

  has_feature :provider_extension if has_provider_extension?

  def self.instances
    list_quantum_networks.collect do |network|
      attrs = get_quantum_network_attrs(network)
      new(
        :ensure                    => :present,
        :name                      => attrs['name'],
        :id                        => attrs['id'],
        :admin_state_up            => attrs['admin_state_up'],
        :provider_network_type     => attrs['provider:network_type'],
        :provider_physical_network => attrs['provider:physical_network'],
        :provider_segmentation_id  => attrs['provider:segmentation_id'],
        :shared                    => attrs['shared']
      )
    end
  end

  def self.prefetch(resources)
    networks = instances
    resources.keys.each do |name|
      if provider = networks.find{ |net| net.name == name }
        resources[name].provider = provider
      end
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    network_opts = Array.new

    if @resource[:shared]
      network_opts << '--shared'
    end

    if @resource[:provider_network_type]
      network_opts << "--provider:network_type=#{@resource[:provider_network_type]}"
    end

    if @resource[:provider_physical_network]
      network_opts << "--provider:physical_network=#{@resource[:provider_physical_network]}"
    end

    if @resource[:provider_segmentation_id]
      network_opts << "--provider:segmentation_id=#{@resource[:provider_segmentation_id]}"
    end

    results = auth_quantum('net-create', '--format=shell', network_opts, resource[:name])

    if results =~ /Created a new network:/
      @network = Hash.new
      results.split("\n").compact do |line|
        @network[line.split('=').first] = line.split('=', 2)[1].gsub(/\A"|"\Z/, '')
      end

      @property_hash = {
        :ensure                    => :present,
        :name                      => resource[:name],
        :id                        => @network[:id],
        :admin_state_up            => @network[:admin_state_up],
        :provider_network_type     => @network[:'provider:network_type'],
        :provider_physical_network => @network[:'provider:physical_network'],
        :provider_segmentation_id  => @network[:'provider:segmentation_id'],
        :shared                    => @network[:shared],
      }
    else
      fail("did not get expected message from network creation, got #{results}")
    end
  end

  def destroy
    auth_quantum('net-delete', id)
    @property_hash[:ensure] = :absent
  end

  def admin_state_up=(value)
    auth_quantum('net-update', "--admin_state_up=#{value}", id)
  end

  def shared=(value)
    auth_quantum('net-update', "--shared=#{value}", id)
  end

  def provider_network_type=(value)
    fail('provider_network_type is read-only')
  end

  def provider_physical_network=(value)
    fail('provider_physical_network is read-only')
  end

  def provider_segmentation_id=(value)
    fail('provider_segmentation_id is read-only')
  end

  def id=(value)
    fail('id is read-only')
  end

end
