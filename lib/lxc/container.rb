class LXC

  # Container Error Class
  class ContainerError < LXCError; end

  # Main Container Class
  #
  # @author Zachary Patten <zachary AT jovelabs DOT com>
  class Container
    require 'timeout'
    require 'tempfile'

    # An array containing the valid container states extracted from the LXC
    # c-source code.
    STATES = %w(stopped starting running stopping aborting freezing frozen thawed not_created).map(&:to_sym)

    # @!method stopped?
    #   Returns true if the container is stopped, false otherwise.
    #   @return [Boolean]
    #
    # @!method starting?
    #   Returns true if the container is starting, false otherwise.
    #   @return [Boolean]
    #
    # @!method running?
    #   Returns true if the container is running, false otherwise.
    #   @return [Boolean]
    #
    # @!method stopping?
    #   Returns true if the container is stopping, false otherwise.
    #   @return [Boolean]
    #
    # @!method aborting?
    #   Returns true if the container is aborting, false otherwise.
    #   @return [Boolean]
    #
    # @!method freezing?
    #   Returns true if the container is freezing, false otherwise.
    #   @return [Boolean]
    #
    # @!method frozen?
    #   Returns true if the container is frozen, false otherwise.
    #   @return [Boolean]
    #
    # @!method thawed?
    #   Returns true if the container is thawed, false otherwise.
    #   @return [Boolean]
    STATES.each do |state|
      define_method "#{state}?" do
        (self.state == state)
      end
    end

    # RegEx pattern for extracting the container state from the "lxc-info"
    # command output.
    REGEX_STATE = /^state:\s+([\w]+)$/

    # RegEx pattern for extracting the container PID from the "lxc-info"
    # command output.
    REGEX_PID = /^pid:\s+([-\d]+)$/

    # Returns the container name
    #
    # @return [String] Container name
    attr_reader :name

    # Returns the parent LXC class instance
    #
    # @return [LXC] Parent LXC class instance.
    attr_reader :lxc

    # @param [Hash] options Options hash.
    # @option options [LXC] :lxc Our parent LXC class instance.
    # @option options [String] :name The name of the container.
    def initialize(options={})
      @lxc  = options[:lxc]
      @name = options[:name]

      raise ContainerError, "You must supply a LXC object!" if @lxc.nil?
      raise ContainerError, "You must supply a container name!" if (@name.nil? || @name.empty?)
    end

    # LXC configuration class
    #
    # Gets the LXC configuration class object
    #
    # @return [LXC::Config] Returns the LXC configuration object.
    def config
      @config ||= LXC::Config.new(@lxc, "/etc/lxc/#{@name}")
    end

    # Create the container
    #
    # Runs the "lxc-create" command.
    #
    # @param [Array] args Additional command-line arguments.
    # @return [Array<String>] Lines of output from the executed command.
    def create(*args)
      self.exec("lxc-create", *args)
    end

    # Destroy the container
    #
    # Runs the "lxc-destroy" command.  If the container has not been stopped
    # first then this will fail unless '-f' is passed as an argument.  See
    # the 'lxc-destroy' man page for more details.
    #
    # @param [Array] args Additional command-line arguments.
    # @return [Array<String>] Lines of output from the executed command.
    def destroy(*args)
      self.exec("lxc-destroy", *args)
    end

    # Start the container
    #
    # Runs the "lxc-start" command.
    #
    # @param [Array] args Additional command-line arguments.
    # @return [Array<String>] Lines of output from the executed command.
    def start(*args)
      self.exec("lxc-start", *args)
    end

    # Start an ephemeral copy of the container
    #
    # Runs the "lxc-start-ephemeral" command.
    #
    # @return [Array<String>] Lines of output from the executed command.
    # @see lxc-start-ephemeral
    def start_ephemeral(*args)
      self.lxc.exec("lxc-start-ephemeral", *args)
    end

    # Clone the container
    #
    # Runs the "lxc-clone" command.
    #
    # @return [Array<String>] Lines of output from the executed command.
    # @see lxc-clone
    def clone(*args)
      self.lxc.exec("lxc-clone", *args)
    end

    # Stop the container
    #
    # Runs the "lxc-stop" command.
    #
    # @param [Array] args Additional command-line arguments.
    # @return [Array<String>] Lines of output from the executed command.
    def stop(*args)
      self.exec("lxc-stop", *args)
    end

    # Restart the container
    def restart(options={})
      self.stop
      self.start
    end
    alias :reload :restart

    # Freeze the container
    #
    # Runs the "lxc-freeze" command.
    #
    # @param [Array] args Additional command-line arguments.
    # @return [Array<String>] Lines of output from the executed command.
    def freeze(*args)
      self.exec("lxc-freeze", *args)
    end

    # Unfreeze (thaw) the container
    #
    # Runs the "lxc-unfreeze" command.
    #
    # @param [Array] args Additional command-line arguments.
    # @return [Array<String>] Lines of output from the executed command.
    def unfreeze(*args)
      self.exec("lxc-unfreeze", *args)
    end

    # Information on the container
    #
    # Runs the "lxc-info" command.
    #
    # @param [Array] args Additional command-line arguments.
    # @return [Array<String>] Lines of output from the executed command.
    def info(*args)
      self.exec("lxc-info", *args).split("\n").uniq.flatten
    end

    # State of the container
    #
    # Runs the "lxc-info" command with the "--state" flag.
    #
    # @param [Array] args Additional command-line arguments.
    # @return [Symbol] Current state of the container.
    def state(*args)
      if self.exists?
        result = self.info("--state", *args).collect{ |str| str.scan(REGEX_STATE) }
        result.flatten!.compact!

        (result.first.strip.downcase.to_sym rescue :unknown)
      else
        :not_created
      end
    end

    # PID of the container
    #
    # Runs the "lxc-info" command with the "--pid" flag.
    #
    # @param [Array] args Additional command-line arguments.
    # @return [Integer] Current PID of the container.
    def pid(*args)
      result = self.info("--pid", *args).collect{ |str| str.scan(REGEX_PID) }
      result.flatten!.compact!

      (result.first.strip.to_i rescue -1)
    end

    # Does the container exist?
    #
    # @return [Boolean] Returns true if the container exists, false otherwise.
    def exists?
      @lxc.exists?(self.name)
    end

    # Run an application inside a container
    #
    # Launches the container, executing the supplied application inside it.
    #
    # @see lxc-execute
    def execute(*args)
      self.exec("lxc-execute", "-f", self.config.filename, "--", *args)
    end

    # Run an application inside a container
    #
    # Executes the supplied application inside a container.  The container must
    # already be running.
    #
    # @see lxc-attach
    def attach(*args)
      self.exec("lxc-attach", "--", *args)
    end

    # Bootstrap a container
    #
    # Renders the supplied text blob inside a container as a script and executes
    # it via lxc-attach.  The container must already be running.
    #
    # @see lxc-attach
    #
    # @param [String] content The content to render in the container and
    #   execute.  This is generally a bash script of some sort for example.
    # @return [String] The output of *lxc-attach*.
    def bootstrap(content)
      output = nil

      ZTK::RescueRetry.try(:tries => 5, :on => ContainerError) do
        tempfile = Tempfile.new("bootstrap")
        lxc_tempfile  = File.join("", "tmp", File.basename(tempfile.path))
        host_tempfile = File.join(self.fs_root, lxc_tempfile)

        self.lxc.runner.file(:target => host_tempfile, :chmod => '0755', :chown => 'root:root') do |file|
          file.puts(content)
        end

        output = self.attach(%(-- /bin/bash #{lxc_tempfile}))

        if !(output =~ /#{lxc_tempfile}: No such file or directory/).nil?
          raise ContainerError, "We could not find the bootstrap file!"
        end
      end

      output
    end

    # Launch a console for the container
    #
    # @see lxc-console
    def console
      self.exec("lxc-console")
    end

    # Wait for a specific container state
    #
    # Runs the "lxc-wait" command.
    #
    # The timeout only works when using remote control via SSH and will orphan
    # the process ('lxc-wait') on the remote host.
    #
    # @param [Symbol,Array] states A single symbol or an array of symbols
    #   representing container states for which we will wait for the container
    #   to change state to.
    # @param [Integer] timeout How long in seconds we will wait before the
    #   operation times out.
    # @return [Boolean] Returns true of the state change happened, false
    #   otherwise.
    def wait(states, timeout=60)
      state_arg = [states].flatten.map do |state|
        state.to_s.upcase.strip
      end.join('|')

      begin
        Timeout.timeout(timeout) do
          self.exec("lxc-wait", "-s", %('#{state_arg}'))
        end
      rescue Timeout::Error => e
        return false
      end

      true
    end

    # Current Memory Usage
    def memory_usage
      result = self.exec(%(lxc-cgroup), %(memory.usage_in_bytes))
      (result.empty? ? 0 : result.to_i)
    end

    # CPU Time in Seconds
    def cpu_usage
      result = self.exec(%(lxc-cgroup), %(cpuacct.usage))
      (result.empty? ? 0 : (result.to_i / 1E9).to_i)
    end

    # Current Disk Usage
    def disk_usage(ephemeral=false)
      result = (@lxc.exec(%(du -sb #{self.fs_root(ephemeral)})).split.first rescue nil)
      ((result.nil? || result.empty?) ? 0 : result.to_i)
    end

    # Linux container command execution wrapper
    #
    # Executes the supplied command by injecting the container name into the
    # argument list and then passes to the arguments to the top-level LXC class
    # exec method.
    #
    # @param [Array] args Additional command-line arguments.
    # @return [Array<String>] Stripped output text of the executed command.
    #
    # @see LXC#exec
    def exec(*args)
      arguments = Array.new
      arguments << args.shift
      arguments << %(-n #{self.name})
      arguments << args
      arguments.flatten!.compact!

      @lxc.exec(*arguments)
    end

    # Root directory for the containers file system
    #
    # @param [Boolean] ephemeral True if we should construct a path to the
    #   union filesystem used by ephemeral containers.  False if we should
    #   construct a traditional path.
    # @return [String] The root directory for the container.
    def fs_root(ephemeral=false)
      if (ephemeral == true)
        File.join(self.container_root, 'delta0')
      else
        File.join(self.container_root, 'rootfs')
      end
    end

    # Static information about the containers filesystems
    #
    # @return [String] The path to the containers fstab.
    def fs_tab
      File.join(self.container_root, 'fstab')
    end

    # Directory for the container
    #
    # @return [String] The directory for the container.
    def container_root
      File.join('/', 'var', 'lib', 'lxc', self.name)
    end

    # Provides a concise string representation of the class
    # @return [String]
    def inspect
      tags = Array.new
      tags << "name=#{self.name.inspect}"
      tags = tags.join(' ')

      "#<LXC::Container #{tags}>"
    end

  end
end
