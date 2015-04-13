#
# Cookbook Name:: docker_deploy
# Recipe:: default
#
# Copyright 2015 TANABE Ken-ichi
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'json'

::Chef::Recipe.send(:include, Docker::Helpers)

include_recipe 'deploy'

file '/tmp/node.json' do
  user 'root'
  owner 'root'
  mode '0600'
  backup false
  content JSON.pretty_generate(node)
end

node['deploy'].each do |application, deploy|
  Chef::Log.info "Start deploying #{application}..."

  opsworks_deploy_dir do
    user deploy['user']
    group deploy['group']
    path deploy['deploy_to']
  end

  docker_image deploy['docker']['image'] do
    tag deploy['docker']['tag']
    notifies :redeploy, "docker_container[#{application}]"
  end

  cur = "#{deploy['deploy_to']}/current"
  directory cur do
    user deploy['user']
    group deploy['group']
  end

  image_id = docker_cmd("inspect -f '{{.Id}}' #{deploy['docker']['image']}:#{deploy['docker']['tag']}", 60).stdout
  file "#{cur}/id" do
    user deploy['user']
    group deploy['group']
    content image_id
    notifies :redeploy, "docker_container[#{application}]"
  end

  template "#{cur}/env" do
    user deploy['user']
    group deploy['group']
    mode '0600'
    action :create
    backup false
    source 'envfile.erb'
    variables :env => deploy['environment']
    notifies :redeploy, "docker_container[#{application}]"
  end

  docker_container application do
    image image_id
    container_name application
    action :run
    detach true
    env_file "#{cur}/env"
    if deploy['docker']['cmd']
      command deploy['docker']['cmd']
    end

    if deploy['docker']['net']
      net deploy['docker']['net']
    end
  end
end
