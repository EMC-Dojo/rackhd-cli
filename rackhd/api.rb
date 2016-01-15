require 'json'
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
      request.body = { status: config["status"] }.to_json
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

    def self.get_active_workflow(config)
      raise 'Please specify a target.' unless config["target"]
      raise 'Please specify a node.' unless config["node"]

      http = Net::HTTP.new("#{config["target"]}", PORT)
      request = Net::HTTP::Get.new("/api/common/nodes/#{config["node"]}/workflows/active")
      response = http.request(request)

      case response
      when Net::HTTPNoContent
        return "n/a"
      when Net::HTTPOK
        return JSON.parse(http.request(request).body)["definition"]["injectableName"]
      end
    end
  end
end
