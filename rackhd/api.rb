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

    def self.delete(config)
      raise 'Please specify a target.' unless config["target"]
      raise 'Please specify a node.' unless config["node"]

      http = Net::HTTP.new("#{config["target"]}", PORT)
      request = Net::HTTP::Delete.new("/api/common/nodes/#{config["node"]}")
      http.request(request)
    end

    def self.set_status(config)
      raise 'Please specify a target.' unless config["target"]
      raise 'Please specify a node.' unless config["node"]
      raise 'Please specify a status.' unless config["status"]

      http = Net::HTTP.new("#{config["target"]}", PORT)
      request = Net::HTTP::Patch.new("/api/common/nodes/#{config["node"]}")
      request.body = {status: config["status"]}.to_json
      request.set_content_type('application/json')
      http.request(request)
    end

    def self.set_amt(config)
      raise 'Please specify a target.' unless config["target"]
      raise 'Please specify a node.' unless config["node"]
      raise 'Please specify a password.' unless config["password"]

      http = Net::HTTP.new("#{config["target"]}", PORT)
      request = Net::HTTP::Get.new("/api/common/nodes/#{config["node"]}")
      response = http.request(request)

      host = JSON.parse(response.body)["name"]
      request = Net::HTTP::Patch.new("/api/common/nodes/#{config["node"]}")
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

    def self.get_active_workflow(config)
      raise 'Please specify a target.' unless config["target"]
      raise 'Please specify a node.' unless config["node"]

      http = Net::HTTP.new("#{config["target"]}", PORT)
      request = Net::HTTP::Get.new("/api/common/nodes/#{config["node"]}/workflows/active")
      response = http.request(request)

      case response
        when Net::HTTPNoContent
          return 'n/a'
        when Net::HTTPOK
          return JSON.parse(response.body)["definition"]["injectableName"]
        else
          return 'n/a'
      end
    end

    def self.restart_node(config)
      raise 'Please specify a target.' unless config["target"]
      raise 'Please specify a node.' unless config["node"]

      http = Net::HTTP.new("#{config["target"]}", PORT)

      request = Net::HTTP::Post.new("/api/common/nodes/#{config["node"]}/workflows")
      request.body = {name: 'Graph.Reboot.Node', options: {defaults: {obmServiceName: 'amt-obm-service'}}}.to_json
      request.set_content_type('application/json')

      resp = http.request(request)
      case resp
        when Net::HTTPCreated
          return 'Successfully kicked off reboot workflow.'
        else
          return 'Failed to kick off reboot workflow.'
      end
    end

    def self.deprovision_node(config)
      raise 'Please specify a target.' unless config["target"]
      raise 'Please specify a node.' unless config["node"]

      http = Net::HTTP.new("#{config["target"]}", PORT)
      request = Net::HTTP::Get.new("/api/common/workflows/library")
      response = http.request(request)

      case response
        when Net::HTTPNoContent
          return "n/a"
        when Net::HTTPOK
          workflows = JSON.parse(http.request(request).body)
          workflows.each do |workflow|
            if workflow["injectableName"].include? 'DeprovisionNode'
              # puts "Found workflow #{workflow["injectableName"]}"

              request = Net::HTTP::Post.new("/api/common/nodes/#{config["node"]}/workflows")
              request.body = {name: workflow["injectableName"], options: {defaults: {obmServiceName: 'amt-obm-service'}}}.to_json
              request.set_content_type('application/json')

              resp = http.request(request)
              case resp
                when Net::HTTPCreated
                  return 'Successfully kicked off deprovision workflow.'
                else
                  return 'Failed to kick off deprovision workflow.'
              end
            end
          end

          return 'No deprovision workflow found on RackHD server.'
      end
    end
  end
end
