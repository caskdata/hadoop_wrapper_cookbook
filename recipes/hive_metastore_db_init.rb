#
# Cookbook Name:: hadoop_wrapper
# Recipe:: hive_metastore_db_init
#
# Copyright © 2014-2017 Cask Data, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe 'hadoop_wrapper::default'
include_recipe 'hadoop::default'
include_recipe 'hadoop::hive_metastore'

# Set up our database
if node['hive'].key?('hive_site') && node['hive']['hive_site'].key?('javax.jdo.option.ConnectionURL') &&
   node['hive']['hive_site'].key?('javax.jdo.option.ConnectionDriverName') &&
   node['hive']['hive_site']['javax.jdo.option.ConnectionDriverName'] != 'org.apache.derby.jdbc.EmbeddedDriver'
  jdo_array = node['hive']['hive_site']['javax.jdo.option.ConnectionURL'].split(':')
  hive_uris = node['hive']['hive_site']['hive.metastore.uris'].gsub('thrift://', '').gsub(':9083', '').split(',')
  # resolve hostnames so that db permissions are also granted for IPs. Mysql fails when hostname looks like an IP.
  begin
    require 'resolv'
    hive_ips = hive_uris.map { |h| Resolv.getaddress(h) }
    hive_ips.each do |ip|
      hive_uris.push(ip) unless hive_uris.include?(ip)
    end
  rescue LoadError, Resolv::ResolvError => e
    Chef::Log.warn("Could not resolve hive.metastore.uris, not explicitly granting db permissions for them : #{e.message}")
  end
  hive_uris.push('localhost')
  db_type = jdo_array[1]
  db_name = jdo_array[3].split('/').last.split('?').first
  db_user =
    if node['hive'].key?('hive_site') && node['hive']['hive_site'].key?('javax.jdo.option.ConnectionUserName')
      node['hive']['hive_site']['javax.jdo.option.ConnectionUserName']
    end
  db_pass =
    if node['hive'].key?('hive_site') && node['hive']['hive_site'].key?('javax.jdo.option.ConnectionPassword')
      node['hive']['hive_site']['javax.jdo.option.ConnectionPassword']
    end
  sql_dir = "#{hadoop_lib_dir}/hive/scripts/metastore/upgrade"

  case db_type
  when 'mysql'
    # Install dependency gem for the database cookbook LWRPs below
    mysql2_chef_gem 'default' do
      action :install
    end

    # Install mysql client libraries via the mysql cookbook LWRP
    mysql_client 'default' do
      action :create
    end

    # Mysql root credentials for LWRPs to create additional users/databases
    mysql_connection_info = {
      host: '127.0.0.1', # if localhost is used, the named socket must also be specified
      username: 'root',
      password: node['mysql']['server_root_password'] # this must be explicitly set
    }

    # database cookbook LWRP to create a named database in "remote" instance
    mysql_database db_name do
      connection mysql_connection_info
      action :create
    end

    # database cookbook LWRP to create a user in "remote" instance
    mysql_database_user db_user do
      connection mysql_connection_info
      password db_pass
      action :create
    end

    # database cookbook LWRP to create a user in "remote" instance
    mysql_database_user "#{db_user}-localhost" do
      connection mysql_connection_info
      username db_user
      password db_pass
      database_name db_name
      host 'localhost'
      privileges [:all]
      action :grant
    end

    # import hive SQL via execute resource
    # connect via 127.0.0.1 instead of localhost to avoid using an incorrect (default) socket file
    execute 'mysql-import-hive-schema' do # ~FC009
      command <<-EOF
        mysql --batch -D#{db_name} -h 127.0.0.1 < $(ls -1 hive-schema-* | sort -n | tail -n 1)
        EOF
      sensitive true
      user 'root'
      action :run
      cwd "#{sql_dir}/mysql"
      environment('MYSQL_PWD' => node['mysql']['server_root_password'])
    end

    hive_uris.each do |hive_host|
      # database cookbook LWRP to create a user in "remote" instance
      mysql_database_user "#{db_user}-#{hive_host}" do
        connection mysql_connection_info
        username db_user
        database_name db_name
        password db_pass
        host hive_host
        privileges [:all]
        action :grant
      end
    end

  when 'postgresql'
    include_recipe 'database::postgresql'
    postgresql_connection_info = {
      host: '127.0.0.1',
      port: node['postgresql']['config']['port'],
      username: 'postgres',
      password: node['postgresql']['password']['postgres']
    }
    postgresql_database db_name do
      connection postgresql_connection_info
      action :create
    end
    postgresql_database_user db_user do
      connection postgresql_connection_info
      password db_pass
      action :create
    end
    execute 'postgresql-import-hive-schema' do # ~FC009
      command <<-EOF
        psql #{db_name} < $(ls -1 hive-schema-* | sort -n | tail -n 1)
        EOF
      sensitive true
      user 'postgres'
      action :run
      cwd "#{sql_dir}/postgres"
      environment('PGPASSWORD' => node['postgresql']['password']['postgres'])
    end
    hive_uris.each do |hive_host|
      postgresql_database_user "#{db_user}-#{hive_host}" do
        connection postgresql_connection_info
        username db_user
        database_name db_name
        password db_pass
        host hive_host
        privileges [:all]
        action :grant
      end
    end
  else
    Chef::Log.info('Only MySQL and PostgreSQL are supported for automatically creating users and databases')
  end
end
