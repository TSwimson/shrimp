#  command_config_file  = "--config=#{options[:command_config_file]}"
module Shrimp
  # start and manage a phantom rasterization server
  class RasterizeServer
    attr_reader :pid
    # phantom wasnt found
    class NoExecutableError < StandardError
      def initialize
        msg = "No phantomjs executable found at
          #{Shrimp.configuration.phantomjs}\n"
        msg << '>> Please install phantomjs - http://phantomjs.org/download.html'
        super(msg)
      end
    end

    def initialize(options = {})
      @options         = options
      @cmd_config_file = get_option(:command_config_file)
      @script_file     = get_option(:script_file)

      if started?
        puts 'Shrimp appears to already be running'
      else
        puts "started: #{start}"
      end

      @pid
    end

    def get_option(option)
      @options.fetch(
        option,
        Shrimp.configuration.default_options[option]
      )
    end

    def started?
      @pid = pid_from_file
      return false unless pid
      begin
        Process.kill(0, pid.to_i)
        true
      rescue Errno::ESRCH
        false
      rescue Errno::EPERM
        true
      end
    end

    def pid_from_file
      @pidfile ||= get_option(:pid_file)
      begin
        File.open(@pidfile, 'rb') { |file| file.read }
      rescue Errno::ENOENT
        nil
      end
    end

    def write_pid_to_file
      @pidfile ||= get_option(:pid_file)
      File.open(@pidfile, 'wb') { |file| file.write(@pid) }
    end

    def start
      @output, input = IO.pipe
      cmd = start_cmd
      puts "Executing #{cmd}"
      @pid = Process.spawn(cmd, out: input)

      ret = @output.gets
      puts "got ret #{ret}"

      write_pid_to_file
      return true if ret.start_with?('listening on port: ')
    end

    def stop
      @output = nil
      Process.detach(@pid)
      Process.kill(15, @pid)
    rescue Errno::ESRCH
      puts 'Error process was doesn\'t appear to be running'
    ensure
      @pid = nil
    end

    def up?
      uri = URI('http://localhost:1225/status')
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 1
      begin
        http.get(uri.request_uri)
      rescue Timeout::Error,
             Errno::EINVAL,
             Errno::ECONNRESET,
             EOFError,
             Errno::ECONNREFUSED => e
        puts "#{e}: #{e.message}"
        return false
      end
      true
    end

    def start_cmd
      "phantomjs --config=#{@cmd_config_file} #{@script_file}"
    end

    # recently moved
    def self.restart_phantom
      if @pid
        begin
          Process.kill('SIGTERM', @pid)
        rescue
          Errno::ESRCH
        end
        @pid = nil
      end
      puts "executing #{cmd}"
      @pid = Process.spawn(cmd)
      sleep(10)
    end

    def cmd
      config_options = Shrimp.configuration.default_options[:command_config_file]
      "phantomjs --config=#{config_options} #{Shrimp::Phantom::SCRIPT_FILE}"
    end
  end
end
