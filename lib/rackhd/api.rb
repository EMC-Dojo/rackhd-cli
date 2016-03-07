require 'json'
require 'net/http'
require 'yaml'
require 'net/ssh'

module RackHD
  class API

    def self.free_nodes(config)
      raise 'Please specify a target.' unless config['target']

      http = Net::HTTP.new(config['target'], config['port'])
      request = Net::HTTP::Get.new('/api/common/nodes')
      nodes = JSON.parse(http.request(request).body)

      nodes.each do |node|
        if node['status'] != 'available'
            node_id = node['id']
            request = Net::HTTP::Patch.new("/api/common/nodes/#{node_id}")
            request.body = {status: 'available'}.to_json
            request.set_content_type('application/json')
            http.request(request)
        end
      end
    end

    def self.get_nodes(config)
      raise 'Please specify a target.' unless config['target']

      http = Net::HTTP.new(config['target'], config['port'])

      request = Net::HTTP::Get.new('/api/common/nodes')
      JSON.parse(http.request(request).body)
    end

    def self.delete(config, node_id)
      raise 'Please specify a target.' unless config['target']

      node_names = config['node_names']

      if node_names.has_value? node_id
        node_names.each do |mac,name|
          if node_id == name
            found_mac = mac
            nodes = get_nodes(config)
            nodes.each do |node|
              if node['name'] == found_mac
                http = Net::HTTP.new(config['target'], config['port'])
                request = Net::HTTP::Delete.new("/api/common/nodes/#{node['id']}")
                http.request(request)
                puts 'Deleted friendly ' + node['id']
                return
              end
            end
          end
        end
      end

      http = Net::HTTP.new(config['target'], config['port'])
      request = Net::HTTP::Delete.new("/api/common/nodes/#{node_id}")
      http.request(request)
    end

    def self.set_status(config, node_id, status)
      raise 'Please specify a target.' unless config['target']

      http = Net::HTTP.new(config['target'], config['port'])
      request = Net::HTTP::Patch.new("/api/common/nodes/#{node_id}")
      request.body = {status: status}.to_json
      request.set_content_type('application/json')
      http.request(request)
    end

    def self.set_amt(config, node_id)
      self.set_obm(config, node_id, "amt")
    end

    def self.set_ipmi(config, node_id)
      self.set_obm(config, node_id, "ipmi")
    end

    def self.delete_orphan_disks(config)
      http = Net::HTTP.new(config['target'], config['port'])
      nodes = get_nodes(config)

      nodes.each do |node|
        if node['cid'] == nil || node['cid'] == ''
          if node['persistent_disk'] != nil && node['persistent_disk']['disk_cid'] != nil
            request = Net::HTTP::Patch.new("/api/common/nodes/#{node['id']}")
            request.body = {
              persistent_disk: {}
            }.to_json
            request.set_content_type('application/json')
            http.request(request)
          end
        end
      end
    end

    def self.get_active_workflow(config, node_id)
      raise 'Please specify a target.' unless config['target']

      http = Net::HTTP.new(config['target'], config['port'])
      request = Net::HTTP::Get.new("/api/common/nodes/#{node_id}/workflows/active")
      response = http.request(request)

      case response
        when Net::HTTPNoContent
          'n/a'
        when Net::HTTPOK
          JSON.parse(response.body)['definition']['injectableName']
        else
          'n/a'
      end
    end

    def self.restart_node(config, node_id)
      raise 'Please specify a target.' unless config['target']

      http = Net::HTTP.new(config['target'], config['port'])

      request = Net::HTTP::Post.new("/api/common/nodes/#{node_id}/workflows")
      request.body = {name: 'Graph.Reboot.Node', options: {defaults: {obmServiceName: 'amt-obm-service'}}}.to_json
      request.set_content_type('application/json')

      resp = http.request(request)

      raise 'Failed to kick off reboot workflow' unless resp.kind_of? Net::HTTPCreated
    end

    def self.deprovision_node(config, node_id)
      raise 'Please specify a target.' unless config['target']

      http = Net::HTTP.new(config['target'], config['port'])
      request = Net::HTTP::Get.new('/api/common/workflows/library')
      response = http.request(request)

      if config['node_names'].values.include? node_id
        mac_addr=String.new
        config['node_names'].each do |k,v|
          if v==node_id
            mac_addr=k
          end
        end

        nodes=get_nodes(config)
        nodes.each do |node|
          if node['name'] == mac_addr
            node_id=node['id']
          end
        end

      end

      case response
        when Net::HTTPNoContent
          puts 'No content'
        when Net::HTTPOK
          workflows = JSON.parse(http.request(request).body)
          workflows.each do |workflow|
            if workflow['injectableName'].include? 'DeprovisionNode'
              request = Net::HTTP::Post.new("/api/common/nodes/#{node_id}/workflows")
              request.body = {name: workflow['injectableName'], options: {defaults: {obmServiceName: 'amt-obm-service'}}}.to_json
              request.set_content_type('application/json')

              resp = http.request(request)

              raise 'Failed to kick off deprovision workflow.' unless resp.kind_of? Net::HTTPCreated
              return
            end
          end
        else
          raise 'No deprovision workflow found on RackHD server.'
      end
    end

    def self.clean_files(config)
      raise 'Please specify a target.' unless config['target']

      http = Net::HTTP.new(config['target'], config['port'])
      request = Net::HTTP::Get.new('/api/common/files/list/all')
      response = http.request(request)

      files = JSON.parse(response.body)
      files.each do |file|
        request = Net::HTTP::Delete.new("/api/common/files/#{file['uuid']}")
        response = http.request(request)
        raise("Error deleting file: #{file['uuid']}") unless response.kind_of? Net::HTTPNoContent
      end

      request = Net::HTTP::Get.new('/api/common/files/list/all')
      response = http.request(request)

      if JSON.parse(response.body).length != 0
        raise('ERROR: Failed to delete all files')
      end

      files
    end

    def self.detach_disk(config, node_id)
      raise 'Please specify a target.' unless config['target']

      http = Net::HTTP.new(config['target'], config['port'])
      request = Net::HTTP::Get.new("/api/common/nodes/#{node_id}")
      response = http.request(request)
      persistent_disk = JSON.parse(response.body)['persistent_disk']
      persistent_disk['attached'] = false

      request = Net::HTTP::Patch.new("/api/common/nodes/#{node_id}")
      request.body = {persistent_disk: persistent_disk}.to_json
      request.set_content_type('application/json')
      http.request(request)
    end

    def self.get_nodes_ips_from_server(config)
      Net::SSH.start(
        config['target'],
        config['server_username'],
        :password => config['server_password']
      ) do |ssh|
        5.times do
          ssh.exec!("sudo ip -s -s neigh flush all")
        end
        ssh.exec!("ping #{config['server_gateway']} -c 1")
        arp_table = ssh.exec!("arp -n")

        result = {}
        arp_table.each_line.with_index do |line, i|
          next if i == 0
          cols = line.split(' ')

          if cols.length == 5
            result[cols[2]] = cols[0]
          end
        end

        result
      end
    end

    private
    def self.set_obm(config, node_id, name)
      raise 'Please specify a target.' unless config['target']
      raise 'Please specify a password.' unless config['password']

      http = Net::HTTP.new(config['target'], config['port'])
      request = Net::HTTP::Get.new("/api/common/nodes/#{node_id}")
      response = http.request(request)

      host = JSON.parse(response.body)['name']
      request = Net::HTTP::Patch.new("/api/common/nodes/#{node_id}")
      request.body = {
        obmSettings: [{
            service: "#{name}-obm-service",
            config: {
              user: config['obm_user'],
              host: host,
              password: config['password']
            }
          }]
      }.to_json
      request.set_content_type('application/json')
      http.request(request)
    end
  end
end
