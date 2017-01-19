#  command_config_file  = "--config=#{options[:command_config_file]}"
module Shrimp
  def self.server
    return @server if @server
    @server = RasterizeServer.new
    @server.initial_setup
    @server
  end

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
      @trys            = 0
      @options         = options
    end

    def initial_setup
      wait_for_lock_to_be_released
      read_pid_from_file

      if pid.zero? || !running? || !responding?
        puts 'pid is blank or process is not running or not responding moving on to restart process'
        return initial_setup unless acquire_lock
        stop if running?
        start
        release_lock
        puts 'started'
      else
        puts "read #{pid} from pidfile and its running and responding :) nothing to do"
      end
    end

    def wait_for_lock_to_be_released(trys = 0)
      if locked?
        if trys >= get_option(:startup_timeout_trys)
          puts 'looks like it failed to release the lock, deleting lock'
          release_lock(true)
        else
          puts "looks like it's locked, waiting for #{get_option(:startup_timeout)} seconds, try: #{trys}/#{get_option(:startup_timeout_trys)}"
          sleep(get_option(:startup_timeout))
          wait_for_lock_to_be_released(trys + 1)
        end
      end
    end

    def restart
      wait_for_lock_to_be_released
      return restart unless acquire_lock
      stop if running?
      start
      release_lock
    end

    def start
      @output, input = IO.pipe
      cmd = start_cmd
      puts "Executing #{cmd}"
      @pid = Process.spawn(cmd, out: input)
      Process.detach(@pid)
      ret = @output.gets
      @output = nil
      puts "got ret #{ret}"
      sleep(0.1)
      if ret.start_with?('listening on: ') && responding?
        write_pid_to_file
        return true
      end

      stop
      return false
    end

    def stop
      Process.kill(15, @pid)
    rescue Errno::ESRCH
      puts 'Error process was doesn\'t appear to be running'
    ensure
      @pid = nil
    end

    def running?
      return false unless pid && pid != 0
      begin
        Process.kill(0, pid.to_i)
        true
      rescue Errno::ESRCH
        false
      rescue Errno::EPERM
        true
      end
    end

    def responding?
      uri = URI("#{url}/status")
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = get_option(:status_check_read_timeout)
      http.open_timeout = get_option(:status_check_open_timeout)
      begin
        http.get(uri.request_uri)
      rescue Timeout::Error,
             Errno::EINVAL,
             Errno::ECONNRESET,
             EOFError,
             Errno::ECONNREFUSED => e
        puts "status check failed #{e}: #{e.message}"
        return false
      end
      true
    end

    def url
      "http://localhost:#{get_option(:port)}"
    end

    private

    def start_cmd
      "#{Shrimp.server_configuration.phantomjs} --config=#{get_option(:phantom_config_file)} #{get_option(:script_file)} #{get_option(:port)}"
    end

    def locked?
      File.directory?(lock_path)
    end

    def lock_path
      get_option(:lock_file)
    end

    def acquire_lock
      FileUtils.mkdir(lock_path)
      @acquired_lock = true
      return true
    rescue Errno::EEXIST
      @acquired_lock = false
      return false
    end

    def release_lock(force = false)
      FileUtils.rmdir(lock_path) if force || @acquired_lock == true
      @acquired_lock = false
    end

    def get_option(option)
      @options.fetch(
        option,
        Shrimp.server_configuration.options[option]
      )
    end

    def read_pid_from_file
      @pidfile ||= get_option(:pid_file)
      begin
        @pid = File.open(@pidfile, 'rb', &:read).to_i
      rescue Errno::ENOENT
        @pid = 0
      end
    end

    def write_pid_to_file(pid = nil)
      @pidfile ||= get_option(:pid_file)
      File.open(@pidfile, 'wb') { |file| file.write(pid || @pid) }
    end

    # recently moved
    # def self.restart_phantom
    #   if @pid
    #     begin
    #       Process.kill('SIGTERM', @pid)
    #     rescue
    #       Errno::ESRCH
    #     end
    #     @pid = nil
    #   end
    #   puts "executing #{cmd}"
    #   @pid = Process.spawn(cmd)
    #   sleep(10)
    # end
  end
end
