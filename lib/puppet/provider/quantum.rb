require 'puppet/util/inifile'
class Puppet::Provider::Quantum < Puppet::Provider

  def self.withenv(hash, &block)
    saved = ENV.to_hash
    hash.each do |name, val|
      ENV[name.to_s] = val
    end

    yield
  ensure
    ENV.clear
    saved.each do |name, val|
      ENV[name] = val
    end
  end

  def self.quantum_credentials
    @quantum_credentials ||= get_quantum_credentials
  end

  def self.get_quantum_credentials
    auth_conf = ['auth_host', 'auth_port', 'auth_protocol',
                'admin_tenant_name', 'admin_user', 'admin_password']
    if quantum_file and quantum_file['keystone_authtoken'] and
      auth_conf.all?{|k| !quantum_file['keystone_authtoken'][k].nil?}

        return Hash[ auth_conf.map { |k| [k, quantum_file['keystone_authtoken'][k].strip] } ]
    else
      raise(Puppet::Error, 'File: /etc/quantum/quantum.conf does not contain all required sections.')
    end
  end

  def quantum_credentials
    self.class.quantum_credentials
  end

  def self.auth_endpoint
    @auth_endpoint ||= get_auth_endpoint
  end

  def self.get_auth_endpoint
    q = quantum_credentials
    "#{q['auth_protocol']}://#{q['auth_host']}:#{q['auth_port']}/v2.0/"
  end

  def self.quantum_file
    return @quantum_file if @quantum_file
    @quantum_file = Puppet::Util::IniConfig::File.new
    @quantum_file.read('/etc/quantum/quantum.conf')
    @quantum_file
  end

  def self.auth_quantum(*args)
    q = quantum_credentials
    authenv = {
      :OS_AUTH_URL    => self.auth_endpoint,
      :OS_USERNAME    => q['admin_user'],
      :OS_TENANT_NAME => q['admin_tenant_name'],
      :OS_PASSWORD    => q['admin_password']
    }
    begin
      withenv authenv do
        quantum(args)
      end
    rescue Exception => e
      if (e.message =~ /\[Errno 111\] Connection refused/) or  (e.message =~ /\(HTTP 400\)/)
        sleep 10
        withenv authenv do
          quantum(args)
        end
      else
       raise(e)
      end
    end
  end

  def auth_quantum(*args)
    self.class.auth_quantum(args)
  end


  private
    def self.list_quantum_networks
      ids = []
      list = auth_quantum('net-list', '--format=csv', '--column=id', '--quote=none')
      (list.split("\n")[1..-1] || []).compact.collect do |line|
        ids << line.strip
      end
      return ids
    end

    def self.list_quantum_extensions
      exts = []
      list = auth_quantum('ext-list', '--format=csv', '--column=alias', '--quote=none')
      (list.split("\n")[1..-1] || []).compact.collect do |line|
        exts << line.strip
      end
      return exts
    end

    def self.get_quantum_network_attrs(id)
      attrs = {}
      net = auth_quantum('net-show', '--format=shell', id)
      (net.split("\n") || []).compact.collect do |line|
        k, v = line.split('=', 2)
        attrs[k] = v.gsub(/\A"|"\Z/, '')
      end
      return attrs
    end

end
