# encoding: UTF-8
require 'spec_helper'

describe Shrimp::RasterizeServer do
  context 'with no initial pid file' do
    before(:example) do
      FileUtils.rmdir(Shrimp.server_configuration.options[:lock_file])
      begin
        FileUtils.rm(Shrimp.server_configuration.options[:pid_file])
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

  context 'with no pid file but a lock file is present' do
    before(:example) do
      begin
        FileUtils.mkdir(Shrimp.server_configuration.options[:lock_file])
      rescue Errno::EEXIST
      end
    end

    it 'starts the rasterization server' do
      a = Shrimp::RasterizeServer.new
      a.initial_setup
      expect(a.responding?).to eq(true)
      a.stop
    end
  end
end
