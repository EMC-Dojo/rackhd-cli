require 'rspec'
require 'webmock/rspec'
require_relative '../rackhd/api'

describe RackHD::API do
  subject { RackHD::API }

  context 'with a target' do
    describe '.get_nodes' do
      it 'returns the list of nodes' do
        rackhd_server = 'my.server'

        nodes_response = File.read('fixtures/nodes.json')

        stub_request(:get, "http://#{rackhd_server}:8080/api/common/nodes")
          .to_return(body: nodes_response)

        nodes = subject.get_nodes(rackhd_server)

        expect(nodes).to match_array(JSON.parse(nodes_response))
      end
    end

    describe '.delete' do
      it 'sends a DELETE request to just that node' do
        rackhd_server = 'my.server'
        node_id = 'node_id'
        stub = stub_request(:delete, "http://#{rackhd_server}:8080/api/common/nodes/#{node_id}")

        subject.delete(rackhd_server, node_id)

        expect(stub).to have_been_requested
      end
    end

    describe '.set_status' do
      it 'sets the provided status' do
        rackhd_server = 'my.server'
        node_id = 'node_id'
        status = 'available'
        stub = stub_request(:patch, "http://#{rackhd_server}:8080/api/common/nodes/#{node_id}")
          .with(body: "{\"status\": \"#{status}\"}", headers: {'Content-Type' => 'application/json'})

        subject.set_status(rackhd_server, node_id, status)

        expect(stub).to have_been_requested
      end
    end

    describe '.set_amt' do
      it 'configures a node to use the amt obm service' do
        rackhd_server = 'my.server'
        node_id = 'node_id'
        password = 'password'

        host = 'my_host'
        stub_request(:get, "http://#{rackhd_server}:8080/api/common/nodes/#{node_id}")
          .to_return(body: {name: host}.to_json)
        stub = stub_request(:patch, "http://#{rackhd_server}:8080/api/common/nodes/#{node_id}")
          .with(body: "{\"obmSettings\":[{\"service\":\"amt-obm-service\",\"config\":{\"host\":\"#{host}\",\"password\":\"#{password}\"}}]}")

        subject.set_amt(rackhd_server, node_id, password)

        expect(stub).to have_been_requested
      end
    end
  end
end
