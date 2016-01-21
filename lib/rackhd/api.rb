require 'json'
require 'net/http'
require 'yaml'

module RackHD
  class API

    PORT = 8080

    def self.get_nodes(config)
      raise 'Please specify a target.' unless config["target"]

      http = Net::HTTP.new("#{config["target"]}", PORT)
      request = Net::HTTP::Get.new("/api/common/nodes")
      JSON.parse(http.request(request).body)
    end

    def self.delete(config, node_id)
      raise 'Please specify a target.' unless config["target"]

      http = Net::HTTP.new("#{config["target"]}", PORT)
      request = Net::HTTP::Delete.new("/api/common/nodes/#{node_id}")
      http.request(request)
    end

    def self.set_status(config, node_id, status)
      raise 'Please specify a target.' unless config["target"]

      http = Net::HTTP.new("#{config["target"]}", PORT)
      request = Net::HTTP::Patch.new("/api/common/nodes/#{node_id}")
      request.body = {status: status}.to_json
      request.set_content_type('application/json')
      http.request(request)
    end

    def self.set_amt(config, node_id)
      raise 'Please specify a target.' unless config["target"]
      raise 'Please specify a password.' unless config["password"]

      http = Net::HTTP.new("#{config["target"]}", PORT)
      request = Net::HTTP::Get.new("/api/common/nodes/#{node_id}")
      response = http.request(request)

      host = JSON.parse(response.body)["name"]
      request = Net::HTTP::Patch.new("/api/common/nodes/#{node_id}")
      request.body = {
        obmSettings: [{
            service: 'amt-obm-service',
            config: {
              host: host,
              password: config["password"]
            }
          }]
      }.to_json
      request.set_content_type('application/json')
      http.request(request)
    end

    def self.delete_orphan_disks(config)
      http = Net::HTTP.new("#{config["target"]}", PORT)
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
      raise 'Please specify a target.' unless config["target"]

      http = Net::HTTP.new("#{config["target"]}", PORT)
      request = Net::HTTP::Get.new("/api/common/nodes/#{node_id}/workflows/active")
      response = http.request(request)

      case response
        when Net::HTTPNoContent
          'n/a'
        when Net::HTTPOK
          JSON.parse(response.body)["definition"]["injectableName"]
        else
          'n/a'
      end
    end

    def self.restart_node(config, node_id)
      raise 'Please specify a target.' unless config["target"]

      http = Net::HTTP.new("#{config["target"]}", PORT)

      request = Net::HTTP::Post.new("/api/common/nodes/#{node_id}/workflows")
      request.body = {name: 'Graph.Reboot.Node', options: {defaults: {obmServiceName: 'amt-obm-service'}}}.to_json
      request.set_content_type('application/json')

      resp = http.request(request)
      case resp
        when Net::HTTPCreated
          puts 'Successfully kicked off reboot workflow.'
        else
          puts 'Failed to kick off reboot workflow.'
      end
    end

    def self.deprovision_node(config, node_id)
      raise 'Please specify a target.' unless config["target"]

      http = Net::HTTP.new("#{config["target"]}", PORT)
      request = Net::HTTP::Get.new("/api/common/workflows/library")
      response = http.request(request)

      case response
        when Net::HTTPNoContent
          puts 'No content'
        when Net::HTTPOK
          workflows = JSON.parse(http.request(request).body)
          workflows.each do |workflow|
            if workflow["injectableName"].include? 'DeprovisionNode'
              request = Net::HTTP::Post.new("/api/common/nodes/#{node_id}/workflows")
              request.body = {name: workflow["injectableName"], options: {defaults: {obmServiceName: 'amt-obm-service'}}}.to_json
              request.set_content_type('application/json')

              resp = http.request(request)
              case resp
                when Net::HTTPCreated
                  puts 'Successfully kicked off deprovision workflow.'
                  return
                else
                  puts 'Failed to kick off deprovision workflow.'
              end
            end
          end
        else
          puts 'No deprovision workflow found on RackHD server.'
      end
    end

    def self.clean_files(config)
      raise 'Please specify a target.' unless config["target"]

      http = Net::HTTP.new("#{config["target"]}", PORT)
      request = Net::HTTP::Get.new("/api/common/files/list/all")
      response = http.request(request)

      files = JSON.parse(response.body)
      files.each do |file|
        request = Net::HTTP::Delete.new("/api/common/files/#{file["uuid"]}")
        response = http.request(request)
        raise("Error deleting file: #{file["uuid"]}") unless response.kind_of? Net::HTTPNoContent
      end

      request = Net::HTTP::Get.new("/api/common/files/list/all")
      response = http.request(request)

      if JSON.parse(response.body).length != 0
        raise("ERROR: Failed to delete all files")
      end

      return files
    end
  end
end
