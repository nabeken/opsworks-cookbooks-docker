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
  opsworks = params[:opsworks_data]

  container_data = params[:container_data]

  Chef::Log.info "Start deploying #{application} in #{opsworks['activity']} phase..."

  opsworks_deploy_dir do
    user deploy['user']
    group deploy['group']
    path "/srv/www/#{application}"
  end

  cur = "/srv/www/#{application}/current"

  directory cur do
    user deploy['user']
    group deploy['group']
  end

  docker_image container_data['image'] do
    action :pull
    tag container_data['tag']
    notifies :redeploy, "docker_container[#{application}]"

    only_if {
      opsworks['activity'] == 'setup' || opsworks['activity'] == 'deploy'
    }
  end

  # we want to redeploy when the environment has been changed
  template "#{cur}/env" do
    user deploy['user']
    group deploy['group']
    mode '0600'
    action :create
    backup false
    source 'envfile.erb'
    variables :env => deploy['environment']
    cookbook 'docker_deploy'

    if opsworks['activity'] == 'setup' || opsworks['activity'] == 'deploy'
      notifies :redeploy, "docker_container[#{application}]"
    end
  end

  if deploy['ssl_support']
    file "#{cur}/cert.pem" do
      user deploy['user']
      group deploy['group']
      mode '0600'
      backup false
      action :create
      content deploy['ssl_certificate']
      notifies :redeploy, "docker_container[#{application}]"
    end

    file "#{cur}/cert.key" do
      user deploy['user']
      group deploy['group']
      mode '0600'
      backup false
      action :create
      content deploy['ssl_certificate_key']
      notifies :redeploy, "docker_container[#{application}]"
    end
  end

  docker_container application do
    image container_data['image']
    tag container_data['tag']

    case opsworks['activity']
    when 'setup', 'deploy'
      action [:run_if_missing]
    when 'undeploy'
      action [:stop, :remove]
    end

    detach true

    if container_data['log_driver']
      log_driver container_data['log_driver']
    end

    if container_data['log_opts']
      log_opts container_data['log_opts']
    end

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
