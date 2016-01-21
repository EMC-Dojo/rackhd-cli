require 'table_print'
require 'thor'
require 'yaml'

require 'rackhd/api'
require 'rackhd/config'

class RackHDCLI < Thor
  class_option :target, :aliases => "-t", :desc => "RackHD server IP address"

  option :node, :aliases => "-n", :desc => "Node to delete"
  desc "delete", "Delete a node from the database"
  def delete
    config = RackHD::Config.load_config(options)

    print "Deleting node #{options['node']}..."
    RackHD::API.delete(config)
    puts 'done'
  end

  desc "get_nodes", "Print a table with information about all nodes"
  def get_nodes
    config = RackHD::Config.load_config(options)

    puts "Nodes on target #{config['target']}:\n\n"
    nodes = RackHD::API.get_nodes(config)
    node_names = config['node_names']
    nodes.each do |node|
      node['cid'] = 'n/a' unless node['cid']
      node['status'] = 'n/a' unless node['status']
      mac_addr = node['name']
      node['name'] = "#{mac_addr} (#{node_names[mac_addr]})" if node_names
      if node['persistent_disk'] && node['persistent_disk']['disk_cid']
        node['disk cid'] = node['persistent_disk']['disk_cid']
      else
        node['disk cid'] = 'n/a'
      end
      node['active workflow'] = RackHD::API.get_active_workflow(config.merge({'node' => node['id']}))
    end

    tp nodes, 'id', 'name', 'cid', 'status', 'disk cid', 'active workflow'
  end

  desc "delete_orphan_disks", "Delete all orphan disks"
  def delete_orphan_disks
    config = RackHD::Config.load_config(options)

    print 'Deleting orphan disks for all nodes...'
    RackHD::API.delete_orphan_disks(config)
    puts 'done'
  end

  option :node, :aliases => "-n", :desc => "Node to deprovision"
  desc "deprovision_node", "Run DeprovisionNode workflow on specified node"
  def deprovision_node
    config = RackHD::Config.load_config(options)

    print "Deprovisioning node #{config["node"]}...\n"
    result = RackHD::API.deprovision_node(config)
    puts result
  end

  option :status, :aliases => "-s", :desc => "Status string (e.g. available, reserved, blocked)"
  option :node, :aliases => "-n", :desc => "Node to update"
  desc "set_status", "Set status on node to specified status"
  def set_status
    config = RackHD::Config.load_config(options)

    print "Setting status on node #{config['node']} to #{config['status']}..."
    RackHD::API.set_status(config)
    puts 'done'
  end

  option :node, :aliases => "-n", :desc => "Node to update"
  option :password, :aliases => "-p", :desc => "AMT password"
  desc "set_amt", "Configure node to use AMT OBM service"
  def set_amt
    config = RackHD::Config.load_config(options)

    print "Configuring AMT for node #{config['node']}..."
    RackHD::API.set_amt(config)
    puts 'done'
  end

  option :node, :aliases => "-n", :desc => "Node to reboot"
  desc "reboot", "Reboot node"
  def reboot
    config = RackHD::Config.load_config(options)

    print "Rebooting node #{config['node']}..."
    RackHD::API.restart_node(config)
    puts 'done'
  end

  option :node, :aliases => "-n", :desc => "Node to rediscover"
  desc "rediscover", "Rediscover node"
  def rediscover
    reboot
    sleep 5
    delete
    puts "Warning: rediscovered node is missing OBM settings"
  end

  option :node, :aliases => "-n", :desc => "Node to rediscover"
  desc "clean", "Delete all files uploaded to RackHD Server"
  def clean
    config = RackHD::Config.load_config(options)

    print "Deleting all uploads..."
    files = RackHD::API.clean_files(config)
    puts 'done'
    puts "Removed #{files.length} files."
  end
end
