require 'table_print'
require 'thor'
require 'yaml'

require 'rackhd/api'
require 'rackhd/config'

class RackHDCLI < Thor
  class_option :target, :aliases => '-t', :desc => 'RackHD server host'
  class_option :port, :aliases => '-p', :desc => 'RackHD server port'

  desc 'delete NODE', 'Delete NODE (nodeid or alias) from the database'
  def delete(node)
    config = RackHD::Config.load_config(options)

    print "Deleting node #{node}..."
    RackHD::API.delete(config, node)
    puts 'done'
  end

  desc 'free-nodes', 'Set all nodes status as available'
  def free_nodes
    config = RackHD::Config.load_config(options)

    print 'Setting status to available for all nodes...'
    RackHD::API.free_nodes(config)
    puts 'done'
  end

  option :with_ips, :aliases => "-a", :desc => "Show IPs of nodes in table"
  desc 'nodes', 'Print a table with information about all nodes'
  def nodes
    config = RackHD::Config.load_config(options)
    puts "Nodes on target #{config['target']}:\n\n"
    nodes = RackHD::API.get_nodes(config)

    if config['with_ips']
      node_ips = RackHD::API.get_nodes_ips_from_server(config)
    end
    node_names = config['node_names']

    nodes.each do |node|
      mac_addr = node['name']
      if config['with_ips']
        node['ip'] = node_ips[mac_addr]
      end
      node['name'] = node_names && node_names[mac_addr] ? "#{node_names[mac_addr]}" : "#{mac_addr}"
      node['obm'] = node['obmSettings'].first['service'].split('-').first
      node['cid'] = 'n/a' unless node['cid']
      node['status'] = 'n/a' unless node['status']
      if node['persistent_disk'] && node['persistent_disk']['disk_cid']
        node['disk cid'] = node['persistent_disk']['disk_cid']
      else
        node['disk cid'] = 'n/a'
      end

      node['active workflow'] = RackHD::API.get_active_workflow(config, node['id'])
    end

    if config['with_ips']
      tp nodes, 'id', 'name', 'obm', 'cid', 'status', 'disk cid', 'active workflow', 'ip'
    else
      tp nodes, 'id', 'name', 'obm', 'cid', 'status', 'disk cid', 'active workflow'
    end
  end

  desc 'node NODE', 'Get node information'
  def node(node)
    config = RackHD::Config.load_config(options)

    print "Getting node information...\n"
    node = RackHD::API.get_node(config, node)
    puts JSON.pretty_generate(node)
  end

  desc 'delete-orphan-disks', 'Delete all orphan disks'
  def delete_orphan_disks
    config = RackHD::Config.load_config(options)

    print 'Deleting orphan disks for all nodes...'
    RackHD::API.delete_orphan_disks(config)
    puts 'done'
  end

  desc 'deprovision NODE', 'Run deprovision workflow on NODE'
  def deprovision(node)
    config = RackHD::Config.load_config(options)
    # check for all flag
    if node.eql? 'all'
      RackHD::API.deprovision_all_nodes(config)
    else
      print "Deprovisioning node #{node}..."
      RackHD::API.deprovision_node(config, node)
      puts 'done'
    end
  end

  desc 'status NODE STATUS', 'Set status on NODE to STATUS'
  def status(node, status)
    config = RackHD::Config.load_config(options)

    print "Setting status on node #{node} to #{status}..."
    RackHD::API.set_status(config, node, status)
    puts 'done'
  end

  desc 'detach-disk NODE', 'Detach disk on NODE'
  def detach_disk(node)
    config = RackHD::Config.load_config(options)

    print "Detaching disk on node #{node}..."
    RackHD::API.detach_disk(config, node)
    puts 'done'
  end

  option :password, :aliases => '-x', :desc => 'AMT password'
  desc 'amt NODE', 'Configure NODE to use AMT OBM service'
  def amt(node)
    config = RackHD::Config.load_config(options)

    print "Configuring AMT for node #{node}..."
    RackHD::API.set_amt(config, node)
    puts 'done'
  end

  option :password, :aliases => '-x', :desc => 'IPMI password'
  desc 'ipmi NODE', 'Configure NODE to use IPMI OBM service'
  def ipmi(node)
    config = RackHD::Config.load_config(options)

    print "Configuring AMT for node #{node}..."
    RackHD::API.set_ipmi(config, node)
    puts 'done'
  end

  desc 'reboot NODE', 'Reboot NODE'
  def reboot(node)
    config = RackHD::Config.load_config(options)

    print "Rebooting node #{node}..."
    RackHD::API.restart_node(config, node)
    puts 'done'
  end

  desc 'rediscover NODE', 'Rediscover node'
  def rediscover(node)
    reboot(node)
    sleep 5
    delete(node)
    puts 'Warning: rediscovered node is missing OBM settings'
  end

  desc 'clean', 'Delete all files uploaded to RackHD Server'
  def clean
    config = RackHD::Config.load_config(options)

    print 'Deleting all uploads...'
    files = RackHD::API.clean_files(config)
    puts 'done'
    puts "Removed #{files.length} files."
  end
end
