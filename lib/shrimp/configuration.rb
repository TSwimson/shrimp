require 'tmpdir'
# outomatically make pages respond with .pdf
module Shrimp
  # config for the rendering
  class Configuration
    attr_accessor :default_options
    attr_writer :phantomjs

    [:format,
     :margin,
     :zoom,
     :orientation,
     :tmpdir,
     :rendering_timeout,
     :rendering_time,
     :command_config_file,
     :viewport_width,
     :viewport_height,
     :max_redirect_count].each do |m|
      define_method("#{m}=") do |val|
        @default_options[m] = val
      end
    end

    def initialize
      @default_options = {
        tmpdir:              Dir.tmpdir,
        rendering_timeout:   100,
        rendering_time:      50,
        command_config_file: File.expand_path('../config.json', __FILE__),
        viewport_width:      600,
        viewport_height:     600,
        max_redirect_count:  0,
        script_file:          File.expand_path('../rasterize-server.js', __FILE__),
        pid_file:             File.expand_path('../../../pidfile', __FILE__)
      }.merge(default_header_footer_attributes).merge(default_paper_attributes)
    end

    def default_header_footer_attributes
      {
        header_content:      nil,
        footer_content:      nil,
        header_size:         '0cm',
        footer_size:         '0cm'
      }
    end

    def default_paper_attributes
      {
        format:              'A4',
        margin:              '1cm',
        zoom:                1,
        orientation:         'portrait'
      }
    end

    def phantomjs
      @phantomjs ||= (
        (`bundle exec which phantomjs` if defined?(Bundler::GemfileError)) ||
          `which phantomjs`
      ).chomp
    end
  end

  class << self
    attr_accessor :configuration
  end

  # Configure Phantomjs someplace sensible,
  # like config/initializers/phantomjs.rb
  #
  # @example
  #   Shrimp.configure do |config|
  #     config.phantomjs = '/usr/local/bin/phantomjs'
  #     config.format = 'Letter'
  #   end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end
end
