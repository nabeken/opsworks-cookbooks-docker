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
extend Chef::Mixin::ShellOut

define :docker_deploy do
  application = params[:name]
  deploy = params[:deploy_data]
  container_data = params[:container_data]

  deploy_user = deploy['user'] || 'root'
  deploy_group = deploy['group'] || 'root'

  Chef::Log.info "Start deploying docker container for #{application}"

  %W{
    /srv/container
    /srv/container/#{application}
    /srv/container/#{application}/current
  }.each do |d|
    directory d do
      user deploy_user
      group deploy_group
    end
  end

  cur = "/srv/container/#{application}/current"

  docker_image container_data['image'] do
    action :pull
    tag container_data['tag']
    notifies :redeploy, "docker_container[#{application}]"
  end

  # we want to redeploy when the environment has been changed
  template "#{cur}/env" do
    user deploy_user
    group deploy_group
    mode '0600'
    action :create
    backup false
    source 'envfile.erb'
    variables :env => deploy['environment']
    cookbook 'docker_deploy'
    notifies :redeploy, "docker_container[#{application}]"
  end

  if deploy['enable_ssl']
    file "#{cur}/cert.pem" do
      user deploy_user
      group deploy_group
      mode '0600'
      backup false
      action :create
      content deploy['ssl_configuration']['certificate']
      notifies :redeploy, "docker_container[#{application}]"
    end

    file "#{cur}/cert.key" do
      user deploy_user
      group deploy_group
      mode '0600'
      backup false
      action :create
      content deploy['ssl_configuration']['private_key']
      notifies :redeploy, "docker_container[#{application}]"
    end
  end

  docker_container application do
    image container_data['image']
    tag container_data['tag']

    action [:run_if_missing]

    detach true

    if container_data['cmd']
      command container_data['cmd']
    end

    if container_data['net']
      network_mode container_data['net']
    end

    if container_data['link']
      links [container_data['link']]
    end

    docker_env = []

    if deploy['ssl_support']
      docker_env << "TLS_CERT=#{deploy['ssl_certificate']}"
      docker_env << "TLS_CERT_KEY=#{deploy['ssl_certificate_key']}"
    end

    deploy['environment'].each do |k, v|
      docker_env << "#{k}=#{v}"
    end

    env docker_env
  end
end

define :docker_undeploy do
  application = params[:name]

  docker_container application do
    action [:delete]
  end
end
