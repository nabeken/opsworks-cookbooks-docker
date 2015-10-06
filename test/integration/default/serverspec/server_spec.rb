require 'spec_helper'

describe port(80) do
  it { should be_listening }
end

describe docker_container('api') do
  its(['Path']) { should eq 'app' }

  its(['.HostConfig.LogConfig.Type']) { should eq 'fluentd' }
  its(['.HostConfig.LogConfig.Config']) { should include({'fluentd-tag' => 'docker.{{.Name}}.{{.ID}}' }) }

  %w{
    PORT=80
    TEST_ENV=HOGE
    TEST_ENV_2=HOGE_2
  }.each do |env|
    its(['Config.Env']) { should include env }
  end
  it { should exist }
  it { should be_running }
end
