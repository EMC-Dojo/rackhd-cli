#!/usr/bin/env ruby

require 'net/http'
require 'optparse'
require 'table_print'
require_relative 'rackhd'

options = {}

ARGV << '-h' if ARGV.empty?

OptionParser.new do |opts|
  opts.banner = "Usage: cli.rb [command] [options]"

  opts.on("-n", "--node node", "ID of node") do |id|
    options[:node] = id
  end

  opts.on("-p", "--password password", "AMT password of the node") do |password|
    options[:password] = password
  end

  opts.on("-s", "--status status", "Status for set_status") do |status|
    options[:status] = status
  end

  opts.on("-t", "--target target", "RackHD Server URI") do |target|
    options[:target] = target
  end

end.parse!

command = ARGV[0]

case command
  when 'delete'
    print "Deleting node #{options[:node]}..."
    RackHD::API.delete(options[:target], options[:node])
    puts "done"

  when 'set_status'
    print "Setting status on node #{options[:node]} to #{options[:status]}..."
    RackHD::API.set_status(options[:target], options[:node], options[:status])
    puts "done"

  when 'get_nodes'
    puts "Nodes on target #{options[:target]}:\n\n"
    nodes = RackHD::API.get_nodes(options[:target])
    nodes.map { |n| n["cid"] = "n/a" unless n["cid"] }
    nodes.map { |n| n["status"] = "n/a" unless n["status"] }
    tp nodes, "id", "name", "cid", "status"

  when 'set_amt'
    print "Configuring AMT for node #{options[:node]}..."
    RackHD::API.set_amt(options[:target],options[:node],options[:password])
    puts "done"
end
