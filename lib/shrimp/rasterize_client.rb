require 'uri'
require 'json'
require 'shellwords'
# outomatically make pages respond with .pdf
module Shrimp
  # no executable found
  class NoExecutableError < StandardError
    def initialize
      msg = "No phantomjs executable found at #{Shrimp.configuration.phantomjs}\n"
      msg << '>> Please install phantomjs - http://phantomjs.org/download.html'
      super(msg)
    end
  end

  # bad source
  class ImproperSourceError < StandardError
    def initialize(msg = nil)
      super("Improper Source: #{msg}")
    end
  end

  # phantom did something weird
  class RenderingError < StandardError
    def initialize(msg = nil)
      super("Rendering Error: #{msg}")
    end
  end

  # manages making requests to phantom was renamed from phantom
  # Rasterize client
  class RasterizeClient
    attr_accessor :source,  :configuration, :outfile
    attr_reader   :options, :cookies,       :result, :error

    # Public: Runs the phantomjs binary
    #
    # Returns the stdout output of phantomjs
    def run
      retrys = 0
      # self.class.start_phantom
      uri = URI(request_string)
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 5
      begin
        http.get(uri.request_uri)
      rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Errno::ECONNREFUSED => e
        raise e if retrys > 2
        puts 'restarting shrimp server'
        self.class.restart_phantom
        retrys += 1
        retry
      end
      true
    end

    def run!
      run
    end

    def outfile
      @outfile ||= "#{options[:tmpdir]}/#{Digest::MD5.hexdigest((Time.now.to_i + rand(9001)).to_s)}.pdf"
    end

    # Public: Returns the phantom rasterize command
    def request_string
      'http://localhost:1225?' +
        { in: @source.to_s, out: outfile }
        .merge(browser_attributes)
        .merge(paper_attributes)
        .merge(footer_attributes)
        .merge(header_attributes)
        .delete_if { |_, v| v.nil? }.map { |k, v| "#{k}=#{v}" }.join('&')
    end

    def browser_attributes
      {
        cookie_file:        dump_cookies,
        rendering_time:     options[:rendering_time],
        timeout:            options[:rendering_timeout],
        viewport_width:     options[:viewport_width],
        viewport_height:    options[:viewport_height],
        max_redirect_count: options[:max_redirect_count]
      }
    end

    def paper_attributes
      {
        paper_format: options[:format],
        zoom_factor:  options[:zoom],
        margin:       options[:margin],
        orientation:  options[:orientation]
      }
    end

    def footer_attributes
      { footer_file: handle_footer, footer_size: options[:footer_size] }
    end

    def header_attributes
      { header_file: handle_header, header_size: options[:header_size] }
    end

    # Public: initializes a new Phantom Object
    #
    # url_or_file             - The url of the html document to render
    # options                 - a hash with options for rendering
    #   * format              - the paper format for the output eg: "5in*7.5in", "10cm*20cm", "A4", "Letter"
    #   * zoom                - the viewport zoom factor
    #   * margin              - the margins for the pdf
    #   * command_config_file - the path to a json configuration file for command-line options
    # cookies                 - hash with cookies to use for rendering
    # outfile                 - optional path for the output file a Tempfile will be created if not given
    #
    # Returns self
    def initialize(url_or_file, options = {}, cookies = {}, outfile = nil)
      @source  = Source.new(url_or_file)
      @options = Shrimp.configuration.default_options.merge(options)
      @cookies = cookies
      @outfile = File.expand_path(outfile) if outfile
      # raise NoExecutableError.new unless File.exists?(Shrimp.configuration.phantomjs)
    end

    # Public: renders to pdf
    # path  - the destination path defaults to outfile
    #
    # Returns the path to the pdf file
    def to_pdf(path = nil)
      @outfile = File.expand_path(path) if path
      run
      @outfile
    end

    # Public: renders to pdf
    # path  - the destination path defaults to outfile
    #
    # Returns a File Handle of the Resulting pdf
    def to_file(path = nil)
      to_pdf(path)
      File.new(@outfile)
    end

    # Public: renders to pdf
    # path  - the destination path defaults to outfile
    #
    # Returns the binary string of the pdf
    def to_string(path = nil)
      File.open(to_pdf(path)).read
    end

    def to_pdf!(path = nil)
      @outfile = File.expand_path(path) if path
      run!
      @outfile
    end

    def to_file!(path = nil)
      to_pdf!(path)
      File.new(@outfile)
    end

    def to_string!(path = nil)
      File.open(to_pdf!(path)).read
    end

    private

    def dump_cookies
      host = @source.url? ? URI.parse(@source.to_s).host : '/'
      json = @cookies.each_with_object([]) do |(k, v), a|
        a.push(name: k, value: v, domain: host)
        a
      end.to_json

      File.open("#{options[:tmpdir]}/#{rand}.cookies", 'w') do |f|
        f.puts json
        f
      end.path
    end

    def handle_header
      return nil unless options[:header_content]

      a = options[:header_content]
      c = a.is_a?(File) ? a.read : a

      File.open("#{options[:tmpdir]}/#{rand}.header", 'w') do |f|
        f.puts c
        f
      end.path
    end

    def handle_footer
      return nil unless options[:footer_content]

      a = options[:footer_content]
      c = a.is_a?(File) ? a.read : a

      File.open("#{options[:tmpdir]}/#{rand}.footer", 'w') do |f|
        f.puts c
        f
      end.path
    end
  end
end
