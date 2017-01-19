require 'shrimp/version'
require 'shrimp/source'
require 'shrimp/server_configuration'
require 'shrimp/render_configuration'
require 'shrimp/rasterize_server'
require 'shrimp/rasterize_client'

at_exit do
  s = Shrimp::RasterizeServer.new
  s.send(:read_pid_from_file)
  if s.running?
    puts 'killing'
    s.stop
  end
end
