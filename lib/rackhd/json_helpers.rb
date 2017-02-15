require 'table_print'
require_relative 'api'
module RackHD
  class JsonHelper
    def self.get_nodes_table(config, nodes)
      node_names = config['node_names']
      nodes.each do |node|
        mac_addr = node['name']
        node['name'] = node_names && node_names[mac_addr] ? "#{node_names[mac_addr]}" : "#{mac_addr}"
        tags = RackHD::API.get_node_tags(config, node['id'])
        node['tags'] = tags
        node['obm'] = node['obms'].empty? ? "" : node['obms'][0]['service']
        node['active workflow'] = RackHD::API.get_active_workflow(config, node['id'])
      end

      tp nodes, 'id', 'name', 'tags', 'obm', 'active workflow'
    end

    private
    def self.get_status_and_cid(tags)
      if tags.size == 2
        return "n/a", tags[1]
      elsif tags.size == 1
        return tags[0], "n/a"
      else # size =0
        return "n/a", "n/a"
      end
    end
  end
end
