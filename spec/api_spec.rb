require 'rspec'
require 'webmock/rspec'
require_relative '../lib/rackhd/api'
require 'net/ssh'

describe RackHD::API do
  subject { RackHD::API }
  let(:node_id) { 'node_id' }
  let(:status) { 'available' }

  let (:rackhd_gateway) { 'fake-gateway'}
  let (:rackhd_host) {'my.server:8080'}
  let (:rackhd_username) {'fake-username'}
  let (:rackhd_password) {'fake-password'}
  let(:config) { {
    'target' => rackhd_host,
    'obm_user' => 'root',
    'password' => 'password',
    'server_username' => rackhd_username,
    'server_password' => rackhd_password,
    'server_gateway' => rackhd_gateway,
    'node_names' => {"c0:3f:d5:60:51:93" => "fakenodealias"}
  }}

  context 'with a target' do
    describe '.rehash' do
      it 'read in config file and build aliases in the same file' do
        nodes_response_body = File.read('fixtures/nodes.json')

        stub_request(:get, "#{config['target']}/api/2.0/nodes")
          .to_return(body: nodes_response_body)

        before_rehash_file = YAML.load_file('fixtures/before_rehash_file.yml')
        modified_file = subject.rehash(config, before_rehash_file)
        after_rehash_file = YAML.load_file('fixtures/after_rehash_file.yml')
        expect(modified_file).to eq(after_rehash_file)
      end
    end

    describe '.get_nodes' do
      it 'returns the list of nodes' do
        nodes_response_body = File.read('fixtures/nodes.json')

        stub_request(:get, "#{config['target']}/api/2.0/nodes")
          .to_return(body: nodes_response_body)

        nodes = subject.get_nodes(config)
        expect(nodes).to match_array(JSON.parse(nodes_response_body))
      end
    end

    describe '.get_node_tags' do
      it 'return all node\'s tags' do
        tag_json = File.read('fixtures/node_tags.json')
        node_id = 'fake_node_id'

        stub_request(:get, "#{config['target']}/api/2.0/nodes/#{node_id}/tags")
          .to_return(body: tag_json)

        tags = RackHD::API.get_node_tags(config, node_id)
        expect(tags).to eq(["reserved", "4c9289ae-f1da"])
      end
    end

    describe '.get_nodes_ips_from_server' do
      let (:ssh_connection) { double('SSH Connection') }
      let (:arp_table) do
        File.read("spec/arp_table.txt")
      end

      before (:each) do
        expect(Net::SSH)
          .to receive(:start)
          .with(rackhd_host, rackhd_username, {:password => rackhd_password})
          .and_yield(ssh_connection)
      end

      it 'return a map between nodes mac address and their ips' do
        expect(ssh_connection).to receive(:exec!).with("sudo ip -s -s neigh flush all").exactly(5).times
        expect(ssh_connection).to receive(:exec!).with("ping #{rackhd_gateway} -c 1")
        expect(ssh_connection).to receive(:exec!).with("arp -n").and_return(arp_table)

        node_ip_map = subject.get_nodes_ips_from_server(config)
        expect(node_ip_map).to eq({
            "48:ee:0c:67:43:68" => "192.168.10.1",
            "c0:3f:d5:63:fe:15" => "172.31.129.102",
            "98:5a:eb:e2:9b:0c" => "192.168.0.99",
            })
      end
    end

    describe '.delete' do
      it 'sends a DELETE request to just that node' do
        stub = stub_request(:delete, "#{config['target']}/api/2.0/nodes/#{node_id}")

        subject.delete(config, node_id)
        expect(stub).to have_been_requested
      end
    end

    describe '.delete_by_alias' do
      it 'sends a DELETE request to just that node' do
        nodes_response_body = File.read('fixtures/nodes.json')

        delete_stub = stub_request(:delete, "#{config['target']}/api/2.0/nodes/node1")
        node_stub = stub_request(:get, "#{config['target']}/api/2.0/nodes")
                           .to_return(body: nodes_response_body)

        subject.delete(config, 'fakenodealias')
        expect(node_stub).to have_been_requested
        expect(delete_stub).to have_been_requested
      end
    end

    describe '.set_status' do
      it 'sets the provided status' do
        stub = stub_request(:patch, "#{config['target']}/api/2.0/nodes/#{node_id}")
                 .with(body: {status: status}.to_json, headers: {'Content-Type' => 'application/json'})

        subject.set_status(config, node_id, status)
        expect(stub).to have_been_requested
      end
    end

    describe '.get_node' do
      it 'get the node information' do
        node_response = File.read('fixtures/node.json')
        stub = stub_request(:get, "#{config['target']}/api/2.0/nodes/#{node_id}")
                  .to_return(body: node_response)
        subject.get_node(config, node_id)
        expect(stub).to have_been_requested
      end
    end

    describe '.free_nodes' do
      context 'all nodes are available' do
        it 'get nodes and would not make patch request' do
          nodes_response_body = File.read('fixtures/nodes.json')

          stub = stub_request(:get, "#{config['target']}/api/2.0/nodes")
            .to_return(body: nodes_response_body)

          subject.free_nodes(config)
          expect(stub).to have_been_requested
        end
      end

      context 'not all the nodes are available' do
        it 'get nodes and will make a patch request' do
          nodes_response_body = File.read('fixtures/nodes_not_all_available.json')

          stub_get = stub_request(:get, "#{config['target']}/api/2.0/nodes")
                   .to_return(body: nodes_response_body)
          stub_node1 = stub_request(:patch, "#{config['target']}/api/2.0/nodes/node1")
                   .with(body: {status: status}.to_json,
                         headers: {'Content-Type' => 'application/json'})

          subject.free_nodes(config)
          expect(stub_get).to have_been_requested
          expect(stub_node1).to have_been_requested
        end
      end
    end

    describe '.space-used' do
      let (:ssh_connection) { double('SSH Connection') }
      let (:used_table) do
        File.read("spec/used_table.txt")
      end

      before (:each) do
        expect(Net::SSH)
          .to receive(:start)
                .with(rackhd_host, rackhd_username, {:password => rackhd_password})
                .and_yield(ssh_connection)
      end

      it 'returns the space in use on RackHD VM' do
        expect(ssh_connection).to receive(:exec!).with("df -h | grep -wE 'Filesystem|/'").and_return(used_table).exactly(1).times
        subject.get_space_used(config)
      end
    end

    describe '.detach_disk' do
      it 'detaches the disk' do
        node_response = File.read('fixtures/node.json')
        stub_request(:get, "#{config['target']}/api/2.0/nodes/#{node_id}")
          .to_return(body: node_response)

        stub = stub_request(:patch, "#{config['target']}/api/2.0/nodes/#{node_id}")
                 .with(body: {persistent_disk: {disk_cid:'node_id-uuid',location:'/dev/sdb',attached:false}}.to_json,
                       headers: {'Content-Type' => 'application/json'})

        subject.detach_disk(config, node_id)
        expect(stub).to have_been_requested
      end
    end

    describe '.set_amt' do
      it 'configures a node to use the amt obm service' do
        host = 'my_host'
        stub_request(:get, "#{config['target']}/api/2.0/nodes/#{node_id}")
          .to_return(body: {name: host}.to_json)
        stub = stub_request(:patch, "#{config['target']}/api/2.0/nodes/#{node_id}")
                 .with(body: "{\"obmSettings\":[{\"service\":\"amt-obm-service\",\"config\":{\"user\":\"root\",\"host\":\"#{host}\",\"password\":\"#{config["password"]}\"}}]}")

        subject.set_amt(config, node_id)
        expect(stub).to have_been_requested
      end
    end

    describe '.set_ipmi' do
      it 'configures a node to use the amt obm service' do
        host = 'my_host'
        stub_request(:get, "#{config['target']}/api/2.0/nodes/#{node_id}")
          .to_return(body: {name: host}.to_json)
        stub = stub_request(:patch, "#{config['target']}/api/2.0/nodes/#{node_id}")
                 .with(body: "{\"obmSettings\":[{\"service\":\"ipmi-obm-service\",\"config\":{\"user\":\"root\",\"host\":\"#{host}\",\"password\":\"#{config["password"]}\"}}]}")

        subject.set_ipmi(config, node_id)
        expect(stub).to have_been_requested
      end
    end

    describe '.delete_orphan_disks' do
      it 'remove disk setting from node without cid' do
        nodes_response = File.read('fixtures/nodes.json')
        stub_request(:get, "#{config['target']}/api/2.0/nodes")
          .to_return(body: nodes_response)

        stub = stub_request(:patch, "#{config['target']}/api/2.0/nodes/node3")
                 .with(body: "{\"persistent_disk\":{}}")

        subject.delete_orphan_disks(config)
        expect(stub).to have_been_requested
      end
    end

    describe '.get_active_workflow' do
      it 'gets the active workflow of a node' do
        workflow_json = File.read('fixtures/workflow.json')

        stub_request(:get, "#{config['target']}/api/2.0/nodes/node_id/workflows?active=true")
          .to_return(body: workflow_json)

        active_workflow_name = subject.get_active_workflow(config, node_id)
        expected_active_workflows = ["W1", "W2"]
        expect(active_workflow_name).to eq(expected_active_workflows)
      end
    end

    describe '.deprovision_node' do
      it 'deprovision node' do
        workflow = 'Graph.BOSH.DeprovisionNode.815b3847-53a9-4fba-a9d6-694abb96ecc8'

        stub_request(:get, "#{config['target']}/api/common/workflows/library")
          .to_return(body: [{injectableName: workflow}].to_json)

        expected_body = {name: workflow, options: {defaults: {obmServiceName: 'amt-obm-service'}}}.to_json

        stub = stub_request(:post, "#{config['target']}/api/2.0/nodes/#{node_id}/workflows")
                 .with(body: expected_body).to_return(status: 201)

        subject.deprovision_node(config, node_id)
        expect(stub).to have_been_requested
      end
    end

    describe '.deprovision_all_nodes' do
      it 'deprovisions all node' do
        workflow = 'Graph.BOSH.DeprovisionNode.815b3847-53a9-4fba-a9d6-694abb96ecc8'

        nodes_response_body = File.read('fixtures/two_nodes.json')

        node_stub = stub_request(:get, "#{config['target']}/api/2.0/nodes")
          .to_return(body: nodes_response_body)

        stub_request(:get, "#{config['target']}/api/common/workflows/library")
          .to_return(body: [{injectableName: workflow}].to_json)

        expected_body = {name: workflow, options: {defaults: {obmServiceName: 'amt-obm-service'}}}.to_json

        stub1 = stub_request(:post, "#{config['target']}/api/2.0/nodes/node1/workflows")
                 .with(body: expected_body).to_return(status: 201)
        stub2 = stub_request(:post, "#{config['target']}/api/2.0/nodes/node2/workflows")
                 .with(body: expected_body).to_return(status: 201)

        subject.deprovision_all_nodes(config)
        expect(node_stub).to have_been_requested
        expect(stub1).to have_been_requested
        expect(stub2).to have_been_requested
      end
    end

    describe '.deprovision_node with friendly name provided' do
      it 'deprovision node' do
        workflow = 'Graph.BOSH.DeprovisionNode.815b3847-53a9-4fba-a9d6-694abb96ecc8'

        stub_workflow = stub_request(:get, "#{config['target']}/api/common/workflows/library")
          .to_return(body: [{injectableName: workflow}].to_json)

        expected_body = {name: workflow, options: {defaults: {obmServiceName: 'amt-obm-service'}}}.to_json

        nodes_response_body = File.read('fixtures/nodes.json')

        node_stub = stub_request(:get, "#{config['target']}/api/2.0/nodes")
          .to_return(body: nodes_response_body)

        stub = stub_request(:post, "#{config['target']}/api/2.0/nodes/node1/workflows")
                 .with(body: expected_body).to_return(status: 201)

        subject.deprovision_node(config, "fakenodealias")
        expect(node_stub).to have_been_requested
        expect(stub).to have_been_requested
      end
    end

    describe '.restart_node' do
      it 'posts a reboot workflow to the specified node' do
        workflow = 'Graph.Reboot.Node'

        expectedBody = {name: workflow, options: {defaults: {obmServiceName: 'amt-obm-service'}}}.to_json

        stub = stub_request(:post, "#{config['target']}/api/2.0/nodes/#{node_id}/workflows")
                 .with(body: expectedBody).to_return(status: 201)

        subject.restart_node(config, node_id)
        expect(stub).to have_been_requested
      end
    end

    describe '.clean_files' do
      it 'deletes files uploaded to the server' do
        config = {'target' => 'my.server'}

        resp1 = [{
          basename: '08191c9b-f127-427a-43af-0fe18fc4c4b8',
          filename: '08191c9b-f127-427a-43af-0fe18fc4c4b8_78e53b30-98dc-4daf-89fb-fe34e1d10cb7',
          uuid: '78e53b30-98dc-4daf-89fb-fe34e1d10cb7',
          md5: '836abba7b4232e3bc505ed74b807bb08',
          sha256: '7723b6443f29a9ef5f94fc6bebc670636a4d0617044204bc70228ed37417dc49',
          version: 0
        },
        {
          basename: '34c57fae-bbaa-4ca0-4761-e64e480d3e13',
          filename: '34c57fae-bbaa-4ca0-4761-e64e480d3e13_8d8792d5-e1ab-419d-9aff-c49c2a29624a',
          uuid: '8d8792d5-e1ab-419d-9aff-c49c2a29624a',
          md5: '936fd42de220997e4b94d3439b7f1501',
          sha256: 'b7eea8206be6f58e2705b1acb93f87bfd81c91b126e5b0fb128422178ef3ccaa',
          version: 0
        }].to_json

        resp2 = [].to_json

        stub_request(:get, "#{config['target']}/api/2.0/files")
          .to_return({ body: resp1 }, { body: resp2 })

        stub1 = stub_request(:delete, "#{config['target']}/api/2.0/files/78e53b30-98dc-4daf-89fb-fe34e1d10cb7")
                 .to_return(status: 204)
        stub2 = stub_request(:delete, "#{config['target']}/api/2.0/files/8d8792d5-e1ab-419d-9aff-c49c2a29624a")
                 .to_return(status: 204)

        deleted_files = subject.clean_files(config)
        expect(stub1).to have_been_requested
        expect(stub2).to have_been_requested
        expect(deleted_files.length).to eq(2)
      end
    end
  end
end
