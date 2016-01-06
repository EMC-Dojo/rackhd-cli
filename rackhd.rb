#!/usr/bin/env ruby

require 'net/http'
require_relative 'rackhd'

command = ARGV.pop
target = ARGV.pop
node = ARGV.pop

case command
  when 'delete'
    RackHD::API.delete(target, node)
end
