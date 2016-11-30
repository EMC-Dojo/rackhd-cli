require 'table_print'
require 'thor'
require 'yaml'

require 'rackhd/api'
require 'rackhd/json_helpers'
require 'rackhd/config'

class RackHDCLI < Thor
  class_option :target, :aliases => '-t', :desc => 'RackHD server host'
  class_option :port, :aliases => '-p', :desc => 'RackHD server port'

  desc 'delete NODE', 'Delete NODE (nodeid or alias) from the database'
  def delete(node)
    config = RackHD::Config.load_config(options)
    node_id = resolve_node_name(config, node)
    print "Deleting node #{node_id}..."
    RackHD::API.delete(config, node_id)
    puts 'done'
  end

  desc 'free-nodes', 'Set all nodes status as available'
  def free_nodes
    config = RackHD::Config.load_config(options)

    print 'Setting status to available for all nodes...'
    RackHD::API.free_nodes(config)
    puts 'done'
  end

  desc 'rehash', 'enable aliases'
  def rehash
    config = RackHD::Config.load_config(options)
    config_file = RackHD::Config.load_config_file
    modified_file = RackHD::API.rehash(config, config_file)
    RackHD::Config.write_config_file(modified_file.to_yaml)
  end

  option :with_ips, :aliases => "-a", :desc => "Show IPs of nodes in table"
  desc 'nodes', 'Print a table with information about all nodes'
  def nodes
    config = RackHD::Config.load_config(options)
    puts "Nodes on target #{config['target']}:\n\n"
    nodes = RackHD::API.get_nodes(config)

    RackHD::JsonHelper.get_nodes_table(config, nodes)
  end

  desc 'node NODE', 'Get node information'
  def node(node)
    config = RackHD::Config.load_config(options)
    print "Getting node information...\n"
    node_id = resolve_node_name(config, node)
    node = RackHD::API.get_node(config, node_id)
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
      node_id = resolve_node_name(config, node)
      print "Deprovisioning node #{node_id}..."
      RackHD::API.deprovision_node(config, node_id)
      puts 'done'
    end
  end

  desc 'space-used', 'Return the space used on the RackHD server'
  def space_used()
    config = RackHD::Config.load_config(options)
    puts RackHD::API.get_space_used(config)
  end

  desc 'status NODE STATUS', 'Set status on NODE to STATUS'
  def status(node, status)
    config = RackHD::Config.load_config(options)
    node_id = resolve_node_name(config, node)
    print "Setting status on node #{node_id} to #{status}..."
    RackHD::API.set_status(config, node_id, status)
    puts 'done'
  end

  desc 'detach-disk NODE', 'Detach disk on NODE'
  def detach_disk(node)
    config = RackHD::Config.load_config(options)
    node_id = resolve_node_name(config, node)
    print "Detaching disk on node #{node_id}..."
    RackHD::API.detach_disk(config, node_id)
    puts 'done'
  end

  option :password, :aliases => '-x', :desc => 'AMT password'
  desc 'amt NODE', 'Configure NODE to use AMT OBM service'
  def amt(node)
    config = RackHD::Config.load_config(options)
    node_id = resolve_node_name(config, node)
    print "Configuring AMT for node #{node_id}..."
    RackHD::API.set_amt(config, node_id)
    puts 'done'
  end

  option :password, :aliases => '-x', :desc => 'IPMI password'
  desc 'ipmi NODE', 'Configure NODE to use IPMI OBM service'
  def ipmi(node)
    config = RackHD::Config.load_config(options)
    node_id = resolve_node_name(config, node)
    print "Configuring AMT for node #{node_id}..."
    RackHD::API.set_ipmi(config, node_id)
    puts 'done'
  end

  desc 'reboot NODE', 'Reboot NODE'
  def reboot(node)
    config = RackHD::Config.load_config(options)
    node_id = resolve_node_name(config, node)
    print "Rebooting node #{node_id}..."
    RackHD::API.restart_node(config, node_id)
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

  private
  def resolve_node_name(config, name)
    node_aliases = config['node_aliases']
    if node_aliases && node_aliases[name]
      return node_aliases[name]
    end

    name
  end
end
