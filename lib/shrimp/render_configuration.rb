require 'tmpdir'
# outomatically make pages respond with .pdf
module Shrimp
  # config for the rendering
  class RenderConfiguration
    class << self
      attr_accessor :configuration

      def default_options
        {
          tmpdir:              Dir.tmpdir,
          rendering_timeout:   100,
          rendering_time:      50,
          viewport_width:      600,
          viewport_height:     600,
          max_redirect_count:  0
        }.merge(default_header_footer_attributes).merge(default_paper_attributes)
      end

      private

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
    end

    attr_accessor :options

    default_options.keys.each do |m|
      define_method("#{m}=") do |val|
        @options[m] = val
      end
    end

    def initialize
      @options = self.class.default_options
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

  def self.render_configuration
    @render_configuration ||= RenderConfiguration.new
  end

  def self.configure_rendering
    yield(render_configuration)
  end
end
