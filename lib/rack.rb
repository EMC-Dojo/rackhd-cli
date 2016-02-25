require 'table_print'
require 'thor'
require 'yaml'

require 'rackhd/api'
require 'rackhd/config'

class RackHDCLI < Thor
  class_option :target, :aliases => '-t', :desc => 'RackHD server host'
  class_option :port, :aliases => '-p', :desc => 'RackHD server port'

  desc 'delete NODE', 'Delete NODE from the database'
  def delete(node)
    config = RackHD::Config.load_config(options)

    print "Deleting node #{node}..."
    RackHD::API.delete(config, node)
    puts 'done'
  end

  desc 'nodes', 'Print a table with information about all nodes'
  def nodes
    config = RackHD::Config.load_config(options)

    puts "Nodes on target #{config['target']}:\n\n"
    nodes = RackHD::API.get_nodes(config)
    node_names = config['node_names']
    nodes.each do |node|
      mac_addr = node['name']
      node['name'] = "#{mac_addr} (#{node_names[mac_addr]})" if node_names
      node['cid'] = 'n/a' unless node['cid']
      node['status'] = 'n/a' unless node['status']
      if node['persistent_disk'] && node['persistent_disk']['disk_cid']
        node['disk cid'] = node['persistent_disk']['disk_cid']
      else
        node['disk cid'] = 'n/a'
      end
      node['active workflow'] = RackHD::API.get_active_workflow(config, node['id'])
    end

    tp nodes, 'id', 'name', 'cid', 'status', 'disk cid', 'active workflow'
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

    print "Deprovisioning node #{node}..."
    RackHD::API.deprovision_node(config, node)
    puts 'done'
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
