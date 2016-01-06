require 'json'

module RackHD
  class API
    def self.delete_all(target)
      raise 'Please specify a target.' unless target

      http = Net::HTTP.new("#{target}:8080")
      request = Net::HTTP::Get.new("/api/common/nodes")
      nodes = JSON.parse(http.request(request).body)

      nodes.each do |node|
        delete(target, node['id'])
      end
    end

    def self.delete(target, node)
      raise 'Please specify a target.' unless target
      raise 'Please specify a node.' unless node

      http = Net::HTTP.new("#{target}:8080")
      request = Net::HTTP::Delete.new("/api/common/nodes/#{node}")
      http.request(request)
    end

    def self.make_available(target, node)
      raise 'Please specify a target.' unless target
      raise 'Please specify a node.' unless node

      http = Net::HTTP.new("#{target}:8080")
      request = Net::HTTP::Patch.new("/api/common/nodes/#{node}")
      request.body = '{"status": "available"}'
      request.set_content_type('application/json')
      http.request(request)
    end
  end
end
