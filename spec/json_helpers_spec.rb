require 'rspec'
require 'webmock/rspec'
require_relative '../lib/rackhd/json_helpers'
require 'net/ssh'


describe RackHD::JsonHelper do
  subject { RackHD::JsonHelper }
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
    'node_names' => {"00:50:56:b8:08:91" => "fakenodealias"}
  }}

  before(:each) do
    $stdout = StringIO.new
    tp.set :io, $stdout
  end

  after(:each) do
    tp.clear :io
  end

  context 'when given a nodes json response' do
    it 'displays a nodes table' do
      tag_json = File.read('fixtures/node_tags.json')
      workflow_json = File.read('fixtures/workflow.json')
      stub_request(:get, "#{config['target']}/api/2.0/nodes/583dee4f65617a2013493904/tags")
        .to_return(body: tag_json)
      stub_request(:get, "#{config['target']}/api/2.0/nodes/583dee4f65617a2013493904/workflows?active=true")
          .to_return(body: workflow_json)
      nodes_response_body = JSON.parse(File.read('fixtures/nodes.json'))
      subject.get_nodes_table(config, nodes_response_body)

      expect($stdout.string).to include('583dee4f65617a2013493904 | fakenodealias | n/a    | 4c9289ae-f1da | ["W1", "W2"]')
    end
  end
end
