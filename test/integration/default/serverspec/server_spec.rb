require 'spec_helper'

describe port(80) do
  it { should be_listening }
end

describe docker_container('nginx') do
  its(['Path']) { should eq 'nginx' }
  its(['Args']) { should eq ['-g', 'daemon off;'] }
  its(['Config.Env']) { should include 'TEST_ENV=HOGE' }
  it { should exist }
  it { should be_running }
end
