require 'rspec'
require 'webmock/rspec'
require_relative '../rackhd/api'

describe RackHD::API do
  subject { RackHD::API }

  context 'with a target' do
    describe '.get_nodes' do
      it 'returns the list of nodes' do
        config = {"target" => 'my.server'}

        nodes_response = File.read('fixtures/nodes.json')

        stub_request(:get, "http://#{config["target"]}:8080/api/common/nodes")
          .to_return(body: nodes_response)

        nodes = subject.get_nodes(config)

        expect(nodes).to match_array(JSON.parse(nodes_response))
      end
    end

    describe '.delete' do
      it 'sends a DELETE request to just that node' do
        config = {"target" => 'my.server', "node" => 'node_id'}
        stub = stub_request(:delete, "http://#{config["target"]}:8080/api/common/nodes/#{config["node"]}")

        subject.delete(config)

        expect(stub).to have_been_requested
      end
    end

    describe '.set_status' do
      it 'sets the provided status' do
        config = {"target" => 'my.server', "node" => 'node_id', "status" => 'available'}
        stub = stub_request(:patch, "http://#{config["target"]}:8080/api/common/nodes/#{config["node"]}")
          .with(body: { status: config["status"] }.to_json, headers: {'Content-Type' => 'application/json'})

        subject.set_status(config)

        expect(stub).to have_been_requested
      end
    end

    describe '.set_amt' do
      it 'configures a node to use the amt obm service' do
        config = {"target" => 'my.server', "node" => 'node_id', "password" => 'password'}

        host = 'my_host'
        stub_request(:get, "http://#{config["target"]}:8080/api/common/nodes/#{config["node"]}")
          .to_return(body: {name: host}.to_json)
        stub = stub_request(:patch, "http://#{config["target"]}:8080/api/common/nodes/#{config["node"]}")
          .with(body: "{\"obmSettings\":[{\"service\":\"amt-obm-service\",\"config\":{\"host\":\"#{host}\",\"password\":\"#{config["password"]}\"}}]}")

        subject.set_amt(config)

        expect(stub).to have_been_requested
      end
    end

    describe '.delete_orphan_disks' do
      it 'remove disk setting from node without cid' do
        config = {"target" => 'my.server', "node" => 'node_id', "password" => 'password'}

        # host = 'my_host'
        nodes_response = File.read('fixtures/nodes.json')
        stub_request(:get, "http://#{config["target"]}:8080/api/common/nodes")
          .to_return(body: nodes_response)

        stub = stub_request(:patch, "http://#{config['target']}:8080/api/common/nodes/node3")
                 .with(body: "{\"persistent_disk\":{}}")

        subject.delete_orphan_disks(config)

        expect(stub).to have_been_requested
      end
    end

    describe '.get_active_workflow' do
      it 'gets the active workflow of a node' do
        config = {"target" => 'my.server', "node" => 'node_id'}

        workflow_name = "Graph.Fake.Workflow.12345"

        stub_request(:get, "http://#{config["target"]}:8080/api/common/nodes/node_id/workflows/active")
          .to_return(body: { definition: { injectableName: workflow_name}}.to_json)

        active_workflow = subject.get_active_workflow(config)

        expect(active_workflow).to eq(workflow_name)
      end
    end

    describe '.deprovision_node' do
      it 'deprovision node' do
        config = {"target" => 'my.server', "node" => 'node_id'}

        workflow1 = 'Graph.BOSH.DeprovisionNode.815b3847-53a9-4fba-a9d6-694abb96ecc7'
        workflow2 = 'Graph.BOSH.DeprovisionNode.815b3847-53a9-4fba-a9d6-694abb96ecc8'

        stub_request(:get, "http://#{config["target"]}:8080/api/common/workflows/library")
          .to_return(body: [{injectableName: workflow1},
              {injectableName: workflow2}].to_json)

        expectedBody = {name: workflow1, options: {defaults: {obmServiceName: 'amt-obm-service'}}}.to_json

        stub = stub_request(:post, "http://#{config['target']}:8080/api/common/nodes/#{config['node']}/workflows")
                 .with(body: expectedBody).to_return(status: 201)

        subject.deprovision_node(config)

        expect(stub).to have_been_requested
      end
    end

    describe '.restart_node' do
      it 'posts a reboot workflow to the specified node' do
        config = {"target" => 'my.server', "node" => 'node_id'}

        workflow = 'Graph.Reboot.Node'

        expectedBody = {name: workflow, options: {defaults: {obmServiceName: 'amt-obm-service'}}}.to_json

        stub = stub_request(:post, "http://#{config['target']}:8080/api/common/nodes/#{config['node']}/workflows")
                 .with(body: expectedBody).to_return(status: 201)

        subject.restart_node(config)

        expect(stub).to have_been_requested
      end
    end
  end
end
