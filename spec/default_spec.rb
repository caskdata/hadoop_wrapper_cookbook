require 'spec_helper'

describe 'hadoop_wrapper::default' do
  context 'on Centos 6.6 x86_64' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'centos', version: 6.6) do |node|
        node.automatic['domain'] = 'example.com'
        node.automatic['memory']['total'] = '4099400kB'
        stub_command(/update-alternatives --display (.+) /).and_return(false)
        stub_command(/test -L /).and_return(false)
      end.converge(described_recipe)
    end

    it 'includes java recipe' do
      expect(chef_run).to include_recipe('java::default')
    end
  end
end
