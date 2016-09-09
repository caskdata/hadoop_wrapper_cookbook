require 'spec_helper'

describe 'hadoop_wrapper::hadoop_yarn_resourcemanager_init' do
  context 'on HDP 2.2.4.2' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'centos', version: 6.6) do |node|
        node.automatic['domain'] = 'example.com'
        node.automatic['memory']['total'] = '4099400kB'
        node.override['hadoop']['yarn_site']['yarn-remote-app-log-dir'] = '/tmp/yarn-app-log-dir'
        node.override['hadoop']['distribution'] = 'hdp'
        node.override['hadoop']['distribution_version'] = '2.2.4.2'
        stub_command(/hdfs dfs -/).and_return(false)
        stub_command(/update-alternatives --display (.+) /).and_return(false)
        stub_command(/jce(.+).zip' | sha256sum/).and_return(false)
        stub_command(%r{test -e /tmp/jce(.+)/}).and_return(false)
        stub_command(%r{diff -q /tmp/jce(.+)/}).and_return(false)
        stub_command(%r{/sys/kernel/mm/(.*)transparent_hugepage/defrag}).and_return(false)
        stub_command(/test -L /).and_return(false)
      end.converge(described_recipe)
    end

    it 'runs initaction-create-hdfs-tmpdir ruby_block' do
      expect(chef_run).to run_ruby_block('initaction-create-hdfs-tmpdir')
    end

    it 'runs initaction-create-yarn-remote-app-log-dir ruby_block' do
      expect(chef_run).to run_ruby_block('initaction-create-yarn-remote-app-log-dir')
    end

    it 'runs initaction-create-yarn-app-mapreduce-am-staging-dir ruby_block' do
      expect(chef_run).to run_ruby_block('initaction-create-yarn-app-mapreduce-am-staging-dir')
    end

    it 'runs initaction-copy-hdp22-mapreduce-tarball ruby_block' do
      expect(chef_run).to run_ruby_block('initaction-copy-hdp22-mapreduce-tarball')
    end

    it 'does not run initaction-copy-iop-mapreduce-tarball ruby_block' do
      expect(chef_run).not_to run_ruby_block('initaction-copy-iop-mapreduce-tarball')
    end
  end

  context 'on IOP 4.1.0.0' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'centos', version: 6.6) do |node|
        node.override['hadoop']['distribution'] = 'iop'
        node.override['hadoop']['distribution_version'] = '4.1.0.0'
        stub_command(/hdfs dfs -/).and_return(false)
        stub_command(/update-alternatives --display (.+) /).and_return(false)
        stub_command(/jce(.+).zip' | sha256sum/).and_return(false)
        stub_command(%r{test -e /tmp/jce(.+)/}).and_return(false)
        stub_command(%r{diff -q /tmp/jce(.+)/}).and_return(false)
        stub_command(%r{/sys/kernel/mm/(.*)transparent_hugepage/defrag}).and_return(false)
        stub_command(/test -L /).and_return(false)
      end.converge(described_recipe)
    end

    it 'does not run initaction-copy-hdp22-mapreduce-tarball ruby_block' do
      expect(chef_run).not_to run_ruby_block('initaction-copy-hdp22-mapreduce-tarball')
    end

    it 'runs initaction-copy-iop-mapreduce-tarball ruby_block' do
      expect(chef_run).to run_ruby_block('initaction-copy-iop-mapreduce-tarball')
    end
  end

  context 'on CDH 5' do
    let(:chef_run) do
      ChefSpec::SoloRunner.new(platform: 'centos', version: 6.6) do |node|
        node.override['hadoop']['distribution'] = 'cdh'
        node.override['hadoop']['distribution_version'] = '5.3.4'
        stub_command(/hdfs dfs -/).and_return(false)
        stub_command(/update-alternatives --display (.+) /).and_return(false)
        stub_command(/jce(.+).zip' | sha256sum/).and_return(false)
        stub_command(%r{test -e /tmp/jce(.+)/}).and_return(false)
        stub_command(%r{diff -q /tmp/jce(.+)/}).and_return(false)
        stub_command(%r{/sys/kernel/mm/(.*)transparent_hugepage/defrag}).and_return(false)
        stub_command(/test -L /).and_return(false)
      end.converge(described_recipe)
    end

    it 'does not run initaction-copy-hdp22-mapreduce-tarball ruby_block' do
      expect(chef_run).not_to run_ruby_block('initaction-copy-hdp22-mapreduce-tarball')
    end

    it 'does not run initaction-copy-iop-mapreduce-tarball ruby_block' do
      expect(chef_run).not_to run_ruby_block('initaction-copy-iop-mapreduce-tarball')
    end
  end
end
