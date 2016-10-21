require 'uri'
require 'json'
require 'shellwords'

module Shrimp
  class NoExecutableError < StandardError
    def initialize
      msg = "No phantomjs executable found at #{Shrimp.configuration.phantomjs}\n"
      msg << ">> Please install phantomjs - http://phantomjs.org/download.html"
      super(msg)
    end
  end

  class ImproperSourceError < StandardError
    def initialize(msg = nil)
      super("Improper Source: #{msg}")
    end
  end

  class RenderingError < StandardError
    def initialize(msg = nil)
      super("Rendering Error: #{msg}")
    end
  end

  class Phantom
    attr_accessor :source, :configuration, :outfile
    attr_reader :options, :cookies, :result, :error
    SCRIPT_FILE = File.expand_path('../rasterize-server.js', __FILE__)

    def self.restart_phantom
      if @pid
        Process.kill('SIGTERM', @pid) rescue Errno::ESRCH
        @pid = nil
      end
      puts "executing phantomjs --config=#{Shrimp.configuration.default_options[:command_config_file]} #{Shrimp::Phantom::SCRIPT_FILE}"
      @pid = Process.spawn("phantomjs --config=#{Shrimp.configuration.default_options[:command_config_file]} #{Shrimp::Phantom::SCRIPT_FILE}")
      sleep(1)
    end

    # Public: Runs the phantomjs binary
    #
    # Returns the stdout output of phantomjs
    def run
      retrys = 0
      # self.class.start_phantom
      uri = URI(cmd)
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 5
      begin
        http.get(uri.request_uri)
      rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Errno::ECONNREFUSED => e

        if retrys < 2
          puts 'restarting shrimp server'
          self.class.restart_phantom
          retrys += 1
          retry
        else
          raise e
        end
      end
      true
    end

    def run!
      run
    end

    # Public: Returns the phantom rasterize command
    def cmd
      cookie_file                       = dump_cookies
      format, zoom, margin, orientation = options[:format], options[:zoom], options[:margin], options[:orientation]
      rendering_time, timeout           = options[:rendering_time], options[:rendering_timeout]
      viewport_width, viewport_height   = options[:viewport_width], options[:viewport_height]
      max_redirect_count                = options[:max_redirect_count]
      @outfile                          ||= "#{options[:tmpdir]}/#{Digest::MD5.hexdigest((Time.now.to_i + rand(9001)).to_s)}.pdf"
      command_config_file               = "--config=#{options[:command_config_file]}"

      footer_file = handle_footer || Dir.tmpdir + "/#{rand}"
      header_file = handle_header || Dir.tmpdir + "/#{rand}"
      footer_size, header_size = options[:footer_size], options[:header_size]

      [
        Shrimp.configuration.phantomjs,
        command_config_file,
        SCRIPT_FILE,
        @source.to_s.shellescape,
        @outfile,
        format,
        zoom,
        margin,
        orientation,
        cookie_file,
        rendering_time,
        timeout,
        viewport_width,
        viewport_height,
        max_redirect_count,
        footer_file,
        footer_size,
        header_file,
        header_size
      ].join(" ")

      'http://localhost:1225?' + {
        in: @source.to_s,
        out: @outfile,
        paper_format: format,
        zoom_factor: zoom,
        margin: margin,
        orientation: orientation,
        cookie_file: cookie_file,
        rendering_time: rendering_time,
        timeout: timeout,
        viewport_width: viewport_width,
        viewport_height: viewport_height,
        max_redirect_count: max_redirect_count,
        footer_file: footer_file,
        footer_size: footer_size,
        header_file: header_file,
        header_size: header_size
      }.map { |k,v| "#{k}=#{v}" }.join('&')
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
    def initialize(url_or_file, options = { }, cookies={ }, outfile = nil)
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
    def to_pdf(path=nil)
      @outfile = File.expand_path(path) if path
      self.run
      @outfile
    end

    # Public: renders to pdf
    # path  - the destination path defaults to outfile
    #
    # Returns a File Handle of the Resulting pdf
    def to_file(path=nil)
      self.to_pdf(path)
      File.new(@outfile)
    end

    # Public: renders to pdf
    # path  - the destination path defaults to outfile
    #
    # Returns the binary string of the pdf
    def to_string(path=nil)
      File.open(self.to_pdf(path)).read
    end

    def to_pdf!(path=nil)
      @outfile = File.expand_path(path) if path
      self.run!
      @outfile
    end

    def to_file!(path=nil)
      self.to_pdf!(path)
      File.new(@outfile)
    end

    def to_string!(path=nil)
      File.open(self.to_pdf!(path)).read
    end

    private

    def dump_cookies
      host = @source.url? ? URI::parse(@source.to_s).host : "/"
      json = @cookies.inject([]) { |a, (k, v)| a.push({ :name => k, :value => v, :domain => host }); a }.to_json
      File.open("#{options[:tmpdir]}/#{rand}.cookies", 'w') { |f| f.puts json; f }.path
    end

    def handle_header
      return nil unless options[:header_content]

      a = options[:header_content]
      c = a.kind_of?(File) ? a.read : a

      File.open("#{options[:tmpdir]}/#{rand}.header", 'w') { |f| f.puts c; f }.path
    end

    def handle_footer
      return nil unless options[:footer_content]

      a = options[:footer_content]
      c = a.kind_of?(File) ? a.read : a

      File.open("#{options[:tmpdir]}/#{rand}.footer", 'w') { |f| f.puts c; f }.path
    end
  end
end
