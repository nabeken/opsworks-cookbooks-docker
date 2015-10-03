require 'spec_helper'

describe port(80) do
  it { should be_listening }
end

describe docker_container('api') do
  its(['Path']) { should eq 'app' }

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
