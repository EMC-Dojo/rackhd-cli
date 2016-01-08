#!/usr/bin/env ruby

require 'net/http'
require 'optparse'
require_relative 'rackhd'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: rackhd.rb delete [options]"

  opts.on("-n", "--node id", "ID of node to delete") do |id|
    options[:node] = id
  end

  opts.on("-p", "--password p", "Password of the node") do |p|
    options[:password] = p
  end

end.parse!

command = ARGV[0]

puts command

case command
  when 'delete'
    target = ARGV.pop
    node = options[:node]

    puts "Deleting #{node}"

    puts RackHD::API.delete(target, node).body
  # when 'nodes'
  #   target = ARGV.pop
  #   node = options[:node]
  #
  #   puts "Deleting #{node}"
  #
  #   puts RackHD::API.delete(target, node)
end
