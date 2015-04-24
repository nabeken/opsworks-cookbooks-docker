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
    tag container_data['tag']
    notifies :create, "file[#{cur}/id]"

    only_if {
      opsworks['activity'] == 'setup' || opsworks['activity'] == 'deploy'
    }
  end

  file "#{cur}/id" do
    user deploy['user']
    group deploy['group']
    content lazy {
      Chef::Mixin::ShellOut.shell_out("docker inspect -f '{{.Id}}' #{container_data['image']}:#{container_data['tag']}", :timeout => 60).stdout
    }

    if opsworks['activity'] == 'setup' || opsworks['activity'] == 'deploy'
      notifies :redeploy, "docker_container[#{application}]"
    end
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

    if opsworks['action'] == 'setup' || opsworks['action'] == 'deploy'
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
    end

    file "#{cur}/cert.key" do
      user deploy['user']
      group deploy['group']
      mode '0600'
      backup false
      action :create
      content deploy['ssl_certificate_key']
    end
  end

  docker_container application do
    image lazy { ::File.open("#{cur}/id") { |f| f.read.strip } }
    container_name application

    case opsworks['activity']
    when 'setup', 'deploy'
      # something is wrong with [:redeploy, :run] so just redeploy here
      action :redeploy
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

    if deploy['ssl_support']
      ENV['TLS_CERT'] = deploy['ssl_certificate']
      ENV['TLS_CERT_KEY'] = deploy['ssl_certificate_key']
      env %w{
        TLS_CERT
        TLS_CERT_KEY
      }
    end
  end
end
