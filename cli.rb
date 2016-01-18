#!/usr/bin/env ruby

require 'net/http'
require 'optparse'
require 'table_print'
require_relative 'rackhd'

options = {}
config = {}

ARGV << '-h' if ARGV.empty?

OptionParser.new do |opts|
  opts.banner = "Usage: cli.rb [command] [options]"

  opts.on("-c", "--config-file file", "Path to config file") do |file|
    if File.exists? (file)
      config = YAML.load_file(file)
    end
  end

  opts.on("-n", "--node node", "ID of node") do |node|
    options["node"] = node
  end

  opts.on("-p", "--password password", "AMT password of the node") do |password|
    options["password"] = password
  end

  opts.on("-s", "--status status", "Status for set_status") do |status|
    options["status"] = status
  end

  opts.on("-t", "--target target", "RackHD Server URI") do |target|
    options["target"] = target
  end

end.parse!

command = ARGV[0]
config.merge!(options)

case command
  when 'delete'
    print "Deleting node #{config["node"]}..."
    RackHD::API.delete(config)
    puts "done"

  when 'delete_orphan_disks'
    print "Deleting orphan disks for all nodes..."
    RackHD::API.delete_orphan_disks(config)
    puts 'done'

  when 'set_status'
    print "Setting status on node #{config["node"]} to #{config["status"]}..."
    RackHD::API.set_status(config)
    puts "done"

  when 'get_nodes'
    puts "Nodes on target #{config["target"]}:\n\n"
    nodes = RackHD::API.get_nodes(config)
    node_names = config["node_names"]
    nodes.each do |node|
      node["cid"] = "n/a" unless node["cid"]
      node["status"] = "n/a" unless node["status"]
      mac_addr = node["name"]
      node["name"] = "#{mac_addr} (#{node_names[mac_addr]})" if node_names
      if node['persistent_disk'] && node['persistent_disk']['disk_cid']
        node['disk cid'] = node['persistent_disk']['disk_cid']
      else
        node['disk cid'] = 'n/a'
      end
      node["active workflow"] = RackHD::API.get_active_workflow(config.merge({"node" => node["id"]}))

    end

    tp nodes, "id", "name", "cid", "status", 'disk cid', 'active workflow'

  when 'set_amt'
    print "Configuring AMT for node #{config["node"]}..."
    RackHD::API.set_amt(config)
    puts "done"
end
