require 'tmpdir'
# outomatically make pages respond with .pdf
module Shrimp
  # config for the rendering
  class ServerConfiguration
    class << self
      attr_accessor :configuration

      def default_options
        {
          phantom_config_file:       File.expand_path('../config.json', __FILE__),
          script_file:               File.expand_path('../rasterize-server.js', __FILE__),
          pid_file:                  File.expand_path('../../../pidfile', __FILE__),
          lock_file:                 File.expand_path('../../../lockfile', __FILE__),
          port:                      2225,
          status_check_open_timeout: 1,
          status_check_read_timeout: 1,
          startup_timeout:           1,
          startup_timeout_trys:      5
        }
      end
    end

    attr_accessor :options
    attr_writer   :phantomjs

    default_options.keys.each do |m|
      define_method("#{m}=") do |val|
        @options[m] = val
      end
    end

    def initialize
      @options = self.class.default_options
    end

    def phantomjs
      @phantomjs ||= (
        (`bundle exec which phantomjs` if defined?(Bundler::GemfileError)) ||
          `which phantomjs`
      ).chomp
    end
  end

  # Configure Phantomjs someplace sensible,
  # like config/initializers/phantomjs.rb
  #
  # @example
  #   Shrimp.configure do |config|
  #     config.phantomjs = '/usr/local/bin/phantomjs'
  #     config.format = 'Letter'
  #   end

  def self.server_configuration
    @server_configuration ||= ServerConfiguration.new
  end

  def self.configure_server
    yield(server_configuration)
    # server
  end
end
