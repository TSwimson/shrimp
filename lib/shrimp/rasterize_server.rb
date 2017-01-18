#  command_config_file  = "--config=#{options[:command_config_file]}"
# if pid file present
#   if pid file reads restarting
#      if trys < 4
#        increment trys
#        wait a third of a second
#        back to top
#      else
#        start the server
#        do the checks
#        write the pid
#      end
#   else if pid is running && if can get status
#     already started
#     return success
#   else
#     write restarting to pidfile
#     try to kill the pid if there is one
#     start the server
#     do the checks
#     write the pid
#   end
# else
#  write resstarting
#  start the server
#  do the checks
#  write the pid
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
      @trys = 0
      @options         = options
      @cmd_config_file = get_option(:command_config_file)
      @script_file     = get_option(:script_file)
    end

    def initial_setup
      read_pid_from_file

      if pid.nil? || pid == '' || (pid.to_i != 0 && !running?)
        puts 'pid is blank or process is not running moving on to restart process'
        begin
          FileUtils.mkdir('shrimp_lock')
        rescue
          initial_setup
          return
        end
        write_pid_to_file('restarting')
        start
        FileUtils.rmdir('shrimp_lock')
        puts 'started'
      elsif pid.to_i != 0 && running?
        puts "read #{pid} from pidfile and its running :) nothing to do"
      elsif pid.to_s.start_with?('restarting')
        if @trys > 4
          puts 'looks like it failed to restart, i\'ll try now'
          @trys = 0
          write_pid_to_file('')
          FileUtils.rmdir('shrimp_lock')
          initial_setup
          return
        end
        puts "looks like its already restarting waiting for a 3rd of a second try: #{@trys}"
        sleep(0.3)
        @trys += 1
        initial_setup
      end
    end

    def get_option(option)
      @options.fetch(
        option,
        Shrimp.configuration.default_options[option]
      )
    end

    def read_pid_from_file
      @pidfile ||= get_option(:pid_file)
      begin
        @pid = File.open(@pidfile, 'rb', &:read)
        @pid = @pid.to_i if @pid.to_i != 0
      rescue Errno::ENOENT
        nil
      end
    end

    def write_pid_to_file(pid = nil)
      @pidfile ||= get_option(:pid_file)
      File.open(@pidfile, 'wb') { |file| file.write(pid || @pid) }
    end

    def start
      @output, input = IO.pipe
      cmd = start_cmd
      puts "Executing #{cmd}"
      @pid = Process.spawn(cmd, out: input)

      ret = @output.gets
      puts "got ret #{ret}"
      if ret.start_with?('listening on port: ') && responding?
        write_pid_to_file
        return true
      end

      return false
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

    def running?
      return false unless pid && pid.to_i != 0
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
