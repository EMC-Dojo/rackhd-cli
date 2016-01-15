require 'json'
require 'yaml'

module RackHD
  class API

    PORT = 8080

    def self.get_nodes(target)
      http = Net::HTTP.new("#{target}", PORT)
      request = Net::HTTP::Get.new("/api/common/nodes")

      JSON.parse(http.request(request).body)
    end

    def self.delete(target, node)

      http = Net::HTTP.new("#{target}", PORT)
      request = Net::HTTP::Delete.new("/api/common/nodes/#{node}")

      http.request(request)
    end

    def self.set_status(target, node, status)
      raise 'Please specify a target.' unless target
      raise 'Please specify a node.' unless node
      raise 'Please specify a status.' unless status

      http = Net::HTTP.new("#{target}", PORT)
      request = Net::HTTP::Patch.new("/api/common/nodes/#{node}")
      request.body = { status: status }.to_json
      request.set_content_type('application/json')
      http.request(request)
    end

    def self.set_amt(target, node, password)
      raise 'Please specify a target.' unless target
      raise 'Please specify a node.' unless node
      raise 'Please specify a password.' unless password

      http = Net::HTTP.new("#{target}", PORT)

      request = Net::HTTP::Get.new("/api/common/nodes/#{node}")

      response = http.request(request)

      host = JSON.parse(response.body)["name"]

      request = Net::HTTP::Patch.new("/api/common/nodes/#{node}")
      request.body = {
        obmSettings: [{
            service: 'amt-obm-service',
            config: {
              host: host,
              password: password
            }
          }]
      }.to_json
      request.set_content_type('application/json')
      http.request(request)
    end
  end

  def self.load_node_names(path)
    YAML.load_file(path)
  end
end
