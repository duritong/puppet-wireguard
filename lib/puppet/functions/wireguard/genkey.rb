Puppet::Functions.create_function(:'wireguard::genkey') do
  # Returns an array containing the wireguard private and public (in this order) key
  # for a certain interface.
  # @param name The interface name.
  # @param path Absolut path to the wireguard key files (default '/etc/wireguard').
  # @return [Array] Returns [$private_key, $public_key].
  # @example Creating private and public key for the interface wg0.
  #   wireguard::genkey('wg0', '/etc/wireguard') => [
  #     '2N0YBID3tnptapO/V5x3GG78KloA8xkLz1QtX6OVRW8=',
  #     'Pz4sRKhRMSet7IYVXXeZrAguBSs+q8oAVMfAAXHJ7S8=',
  #   ]
  dispatch :genkey do
    required_param 'String', :name
    optional_param 'String', :path
    return_type 'Array'
  end

  def gen_privkey(private_key_path, public_key_path)
    unless File.exists?(private_key_path)
      private_key = Puppet::Util::Execution.execute(
        ['/usr/bin/wg', 'genkey'],
        {:failonfail => true, },
      )
      File.open(private_key_path, 'w') do |f|
        f << private_key
      end
      File.delete(public_key_path) if File.exist?(public_key_path)
    end
  end

  def gen_pubkey(private_key_path, public_key_path)
    unless File.exists?(public_key_path)
      # Workardound for https://tickets.puppetlabs.com/browse/SERVER-2683
      #public_key = Puppet::Util::Execution.execute(
      #  ['/usr/bin/wg', 'pubkey'],
      #  {:failonfail => true,
      #   :stdinfile => private_key_path},
      #)
      public_key = `/usr/bin/wg pubkey < #{private_key_path} 2>&1`
      if $?.to_i > 0
        raise "Error while generating pubkey (Exitcode: #{$?.to_i}): #{public_key}"
      end
      File.open(public_key_path, 'w') do |f|
        f << public_key
      end
    end
  end

  def genkey(name, path='/etc/wireguard')
    private_key_path = File.join(path, "#{name}.key")
    public_key_path = File.join(path, "#{name}.pub")
    [private_key_path,public_key_path].each do |p|
      raise Puppet::ParseError, "#{p} is a directory" if File.directory?(p)
      dir = File.dirname(p)
      raise Puppet::ParseError, "#{dir} is not writable" if not File.writable?(dir)
    end

    gen_privkey(private_key_path, public_key_path)
    gen_pubkey(private_key_path, public_key_path)
    [File.read(private_key_path),File.read(public_key_path)]
  end
end

# vim: set ts=2 sw=2 :
