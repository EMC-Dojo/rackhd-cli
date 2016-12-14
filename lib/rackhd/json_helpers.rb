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
        #//Do logic to get status and cid
        # node['status'], node['cid'] = self.get_status_and_cid(tags)
        # node['obm'].each do |obmSetting|
        # end

        # node['cid'] = 'n/a' unless node['cid']
        # node['status'] = 'n/a' unless node['status']
        # if node['persistent_disk'] && node['persistent_disk']['disk_cid']
        #  node['disk cid'] = node['persistent_disk']['disk_cid']
        # else
        #  node['disk cid'] = 'n/a'
        # end

        node['active workflow'] = RackHD::API.get_active_workflow(config, node['id'])
      end

      # if config['with_ips']
      #   tp nodes, 'id', 'name', 'obm', 'cid', 'status', 'disk cid', 'active workflow', 'ip'
      # else
      tp nodes, 'id', 'name', 'tags', 'active workflow'
      # end
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
