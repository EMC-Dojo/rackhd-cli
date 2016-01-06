require 'rspec'
require 'webmock/rspec'
require_relative '../rackhd/api'

describe RackHD::API do
  subject { RackHD::API }

  context 'with no target' do
    it 'fails with an error' do
      expect { subject.delete(nil, 'whatever') }.to raise_error 'Please specify a target.'
    end
  end

  context 'with a target' do
    describe '.delete' do
      it 'sends a DELETE request to just that node' do
        rackhd_server = 'my.server'
        node_id = 'node_id'
        stub = stub_request(:delete, "http://#{rackhd_server}:8080/api/common/nodes/#{node_id}")

        subject.delete(rackhd_server, node_id)

        expect(stub).to have_been_requested
      end
    end

    describe '.delete_all' do
      it 'sends a DELETE request to all nodes' do
        rackhd_server = 'my.server'
        nodes_response = File.read('fixtures/nodes.json')

        stub_request(:get, "http://#{rackhd_server}:8080/api/common/nodes")
          .to_return(body: nodes_response)
        node_stub1 = stub_request(:delete, "http://#{rackhd_server}:8080/api/common/nodes/node1")
        node_stub2 = stub_request(:delete, "http://#{rackhd_server}:8080/api/common/nodes/node2")


        subject.delete_all(rackhd_server)

        expect(node_stub1).to have_been_requested
        expect(node_stub2).to have_been_requested
      end
    end

    describe '.make_available' do
      it 'makes a node available' do
        rackhd_server = 'my.server'
        node_id = 'node_id'
        stub = stub_request(:patch, "http://#{rackhd_server}:8080/api/common/nodes/#{node_id}")
                 .with(:body => '{"status":"available"}', :headers => {'Content-Type' => 'application/json'})

        subject.make_available(rackhd_server, node_id)

        expect(stub).to have_been_requested
      end
    end
  end
end
