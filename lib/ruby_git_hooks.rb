require "ruby_git_hooks/version"

# TODO: load this stuff on demand.  Eventually it will be crushingly expensive
# to fully pre-fetch all filenames, changed files, diffs, etc.  For right now,
# screw it, it's a prototype.  The API will work fine when the implementation
# gets fixed up.

# TODO: wrap git calls in some saner way.  Not sure Grit counts as "saner".

module RubyGitHooks
  # This isn't all hook names, just the ones we already support.
  CAN_FAIL_HOOKS = [ "pre-commit", "pre-receive" ]
  NO_FAIL_HOOKS = [ "post-receive", "post-commit" ]
  HOOK_NAMES = CAN_FAIL_HOOKS + NO_FAIL_HOOKS
  # applypatch-msg, pre-applypatch, post-applypatch
  # prepare-commit-msg, commit-msg
  # pre-rebase, post-checkout, post-merge, update, post-update,
  # pre-auto-gc, post-rewrite

  class Hook
    class << self
      # What hooks are running
      attr_reader :registered_hooks

      # What command line was run
      attr_reader :run_as

      # What directory to run from
      attr_reader :run_from

      # What git hook is being run
      attr_reader :run_as_hook

      # Array of what files were changed
      attr_accessor :files_changed

      # Latest contents of all changed files
      attr_accessor :file_contents

      # A human-readable diff per file
      attr_accessor :file_diffs

      # All filenames in repo
      attr_accessor :ls_files
    end

    # Instances of Hook delegate these methods to the class methods.
    HOOK_INFO = [ :files_changed, :file_contents, :file_diffs, :ls_files ]
    HOOK_INFO.each do |info_method|
      define_method(info_method) do |*args, &block|
        Hook.send(info_method, *args, &block)
      end
    end

    HOOK_TYPE_SETUP = {

      # Pre-receive gets no args, but STDIN with a list of changes.
      "pre-receive" => proc {
        changes = []
        STDIN.each_line do |line|
          base, commit, ref = line.strip.split
          changes.push [base, commit, ref]
        end
        self.files_changed = []
        self.file_contents = {}
        self.file_diffs = {}
        changes.each do |base, commit, ref|
          self.files_changed += Hook.shell!("git diff --name-only #{base}..#{commit}").split("\n")
          files_changed.each do |file_changed|
            file_contents[file_changed] = Hook.shell!("git show #{commit}:#{file_changed}")
            file_diffs[file_changed] = Hook.shell!("git log -p #{commit} -- #{file_changed}")
          end
        end

        self.ls_files = Hook.shell!("git ls-tree --full-tree --name-only -r HEAD").split("\n")
      },

      "pre-commit" => proc {
        self.files_changed = Hook.shell!("git diff --name-only --cached").split("\n")
        self.file_contents = {}
        self.file_diffs = {}

        files_changed.each do |file_changed|
          file_diffs[file_changed] = Hook.shell!("git diff --cached #{file_changed}")
          file_contents[file_changed] = File.read(file_changed)
        end

        self.ls_files = Hook.shell!("git ls-files").split("\n")
      },
    }

    def self.initial_setup
      @run_from = Dir.getwd
      @run_as = $0
    end

    def setup
      Dir.chdir Hook.run_from do
        yield
      end

    ensure
      # Nothing yet
    end

    def self.get_hooks_to_run(hook_specs)
      @registered_hooks ||= {}

      hook_specs.flat_map do |spec|
        if @registered_hooks[spec]
          @registered_hooks[spec]
        elsif spec.is_a?(Hook)
          [ spec ]
        elsif spec.is_a?(String)
          # A string is assumed to be a class name
          @registered_hooks[Object.const_get(spec)]
        else
          raise "Can't find hook for specification: #{spec.inspect}!"
        end
      end
    end

    # Run takes a list of hook specifications.
    # Those can be Hook classnames or instances of type
    # Hook.
    #
    # @param hook_specs Array[Hook or Class or String] A list of hooks or hook classes
    def self.run(*hook_specs)
      initial_setup

      run_as_specific_githook

      # By default, run all hooks
      hooks_to_run = get_hooks_to_run(hook_specs.flatten)

      hooks_to_run.each do |hook|
        begin
          hook.setup { hook.check }  # Re-init each time, just in case
        rescue
          # Failed.  Return non-zero if that makes a difference.
          STDERR.puts "Hook #{hook.inspect} raised exception: #{$!.inspect}!"
          if CAN_FAIL_HOOKS.include?(@run_as_hook)
            STDERR.puts "Exiting!"
            exit 1
          end
        end
      end
    end

    def self.run_as_specific_githook
      @run_as_hook = HOOK_NAMES.detect { |hook| @run_as.include?(hook) }
      unless @run_as_hook
        STDERR.puts "Name #{@run_as.inspect} doesn't include " +
          "any of: #{HOOK_NAMES.inspect}"
        exit 1
      end
      unless HOOK_TYPE_SETUP[@run_as_hook]
        STDERR.puts "No setup defined for hook type #{@run_as_hook.inspect}!"
        exit 1
      end
      self.instance_eval &HOOK_TYPE_SETUP[@run_as_hook]
    end

    def self.register(hook)
      @registered_hooks ||= {}
      @registered_hooks[hook.class.name] ||= []
      @registered_hooks[hook.class.name].push hook
    end

    # TODO: This should capture both output channels,
    # check better for failure, possibly do more shell
    # parsing...
    def self.shell!(*args)
      output = `#{args.join(" ")}`

      unless $?.success?
        STDERR.puts "Job #{args.inspect} failed in dir #{Dir.getwd.inspect}"
        STDERR.puts "Failed job output:\n#{output}\n======"
        raise "Exec of #{args.inspect} failed: #{$?}!"
      end

      output
    end
  end

  def self.run(*args)
    Hook.run args
  end

  def self.register(*args)
    Hook.register args
  end
end
