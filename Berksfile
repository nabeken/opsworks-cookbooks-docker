# vim: set ft=ruby:
source "https://supermarket.chef.io"

metadata

# just a dirty hack..
if ENV['NO_OPSWORKS']
  group :kitchen do
    opsworks_repo = 'https://github.com/aws/opsworks-cookbooks.git'
    opsworks_branch = 'release-chef-11.10'

    %w{
      dependencies
      deploy
      gem_support
      mod_php5_apache2
      opsworks_agent_monit
      opsworks_aws_flow_ruby
      opsworks_commons
      opsworks_initial_setup
      opsworks_java
      opsworks_nodejs
      scm_helper
      ssh_users
    }.each do |c|
      cookbook c, git: opsworks_repo, branch: opsworks_branch, rel: c
    end
  end

  group :integration do
    cookbook 'td-agent'
    cookbook 'docker_deploy_test', :path => './test/cookbooks/docker_deploy_test'
  end
end
