#
# Cookbook Name:: docker_deploy
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

require 'chef/mixin/shell_out'

define :docker_deploy do
  application = params[:name]
  deploy = params[:deploy_data]
  opsworks = params[:opsworks_data]

  container_data = params[:container_data]

  Chef::Log.info "Start deploying #{application}..."

  opsworks_deploy_dir do
    user deploy['user']
    group deploy['group']
    path deploy['deploy_to']
  end

  cur = "#{deploy['deploy_to']}/current"

  docker_image container_data['image'] do
    tag container_data['tag']
    notifies :create, "file[#{cur}/id]"
  end

  directory cur do
    user deploy['user']
    group deploy['group']
  end

  file "#{cur}/id" do
    user deploy['user']
    group deploy['group']
    content lazy {
      Chef::Mixin::ShellOut.shell_out("docker inspect -f '{{.Id}}' #{container_data['image']}:#{container_data['tag']}", :timeout => 60).stdout
    }
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
    cookbook 'docker_deploy'
    notifies :redeploy, "docker_container[#{application}]"
  end

  docker_container application do
    image lazy { ::File.open("#{cur}/id") { |f| f.read.strip } }
    container_name application

    case opsworks['activity']
    when 'deploy'
      action :run
    when 'undeploy'
      action [:stop, :remove]
    end

    detach true
    env_file "#{cur}/env"
    if container_data['cmd']
      command container_data['cmd']
    end

    if container_data['net']
      net container_data['net']
    end
  end
end
