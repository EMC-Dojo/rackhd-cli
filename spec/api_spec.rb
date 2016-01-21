require 'rspec'
require 'webmock/rspec'
require_relative '../lib/rackhd/api'

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

        expected_body = {name: workflow1, options: {defaults: {obmServiceName: 'amt-obm-service'}}}.to_json

        stub = stub_request(:post, "http://#{config['target']}:8080/api/common/nodes/#{config['node']}/workflows")
                 .with(body: expected_body).to_return(status: 201)

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

    describe '.clean_files' do
      it 'deletes files uploaded to the server' do
        config = {"target" => 'my.server'}

        resp1 = [{
           "basename": "08191c9b-f127-427a-43af-0fe18fc4c4b8",
           "filename": "08191c9b-f127-427a-43af-0fe18fc4c4b8_78e53b30-98dc-4daf-89fb-fe34e1d10cb7",
           "uuid": "78e53b30-98dc-4daf-89fb-fe34e1d10cb7",
           "md5": "836abba7b4232e3bc505ed74b807bb08",
           "sha256": "7723b6443f29a9ef5f94fc6bebc670636a4d0617044204bc70228ed37417dc49",
           "version": 0
         },
         {
           "basename": "34c57fae-bbaa-4ca0-4761-e64e480d3e13",
           "filename": "34c57fae-bbaa-4ca0-4761-e64e480d3e13_8d8792d5-e1ab-419d-9aff-c49c2a29624a",
           "uuid": "8d8792d5-e1ab-419d-9aff-c49c2a29624a",
           "md5": "936fd42de220997e4b94d3439b7f1501",
           "sha256": "b7eea8206be6f58e2705b1acb93f87bfd81c91b126e5b0fb128422178ef3ccaa",
           "version": 0
         }].to_json

        resp2 = [].to_json

        stub_request(:get, "http://#{config['target']}:8080/api/common/files/list/all")
          .to_return({ body: resp1 }, { body: resp2 })

        stub1 = stub_request(:delete, "http://#{config['target']}:8080/api/common/files/78e53b30-98dc-4daf-89fb-fe34e1d10cb7")
                 .to_return(status: 204)
        stub2 = stub_request(:delete, "http://#{config['target']}:8080/api/common/files/8d8792d5-e1ab-419d-9aff-c49c2a29624a")
                 .to_return(status: 204)

        deleted_files = subject.clean_files(config)

        expect(stub1).to have_been_requested
        expect(stub2).to have_been_requested

        expect(deleted_files.length).to eq(2)
      end
    end
  end
end
