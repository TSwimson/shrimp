# encoding: UTF-8
require 'spec_helper'
at_exit do
  s = Shrimp::RasterizeServer.new
  s.read_pid_from_file
  if s.running
    puts 'killing'
    s.stop
  end
end

describe Shrimp::RasterizeServer do
  context 'with no initial pid file' do
    before(:example) do
      FileUtils.rmdir('shrimp_lock')
      begin
        FileUtils.rm(Shrimp.configuration.default_options[:pid_file])
      rescue Errno::ENOENT
      end
    end

    it 'starts the rasterization server' do
      a = Shrimp::RasterizeServer.new
      a.initial_setup
      expect(a.responding?).to eq(true)
      a.stop
    end

    it 'uses the already started server if you create another' do
      a = Shrimp::RasterizeServer.new
      a.initial_setup
      b = Shrimp::RasterizeServer.new
      b.initial_setup

      expect(b.pid).to eq(a.pid)
      expect(b.responding?).to eq(true)
      a.stop
    end
  end
end
