require "ruby_git_hooks/version"

# TODO: load this stuff on demand.  Eventually it will be crushingly expensive
# to fully pre-fetch all filenames, changed files, diffs, etc.  For right now,
# screw it, it's a prototype.  The API will work fine when the implementation
# gets fixed up.

# TODO: wrap git calls in some saner way.  Grit would be saner than this.

# TODO: store file status in addition to names of files_changed

module RubyGitHooks
  # This isn't all hook names, just the ones we already support.
  CAN_FAIL_HOOKS = [ "pre-commit", "pre-receive", "commit-msg" ]
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

      # Whether .run has ever been called
      attr_reader :has_run

      # Array of what files were changed
      attr_accessor :files_changed

      # Latest contents of all changed files
      attr_accessor :file_contents

      # A human-readable diff per file
      attr_accessor :file_diffs

      # All filenames in repo
      attr_accessor :ls_files

      # All current commits (sometimes empty)
      attr_accessor :commits

      # Commit message for current commit
      attr_accessor :commit_message
    end

    # Instances of Hook delegate these methods to the class methods.
    HOOK_INFO = [ :files_changed, :file_contents, :file_diffs, :ls_files,
                  :commits, :commit_message ]
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
        self.commits = changes.map { |c| c[1] }

        self.files_changed = []
        self.file_contents = {}
        self.file_diffs = {}
        changes.each do |base, commit, ref|
          files_with_status = Hook.shell!("git diff --name-status #{base}..#{commit}").split("\n")
          files_with_status.each do |f|
            status, file_changed = f.scan(/([ACDMRTUXB])\s+(\S+)$/).flatten
            self.files_changed << file_changed

            file_diffs[file_changed] = Hook.shell!("git log -p #{commit} -- #{file_changed}")
            file_contents[file_changed] = status == "D"? "": Hook.shell!("git show #{commit}:#{file_changed}")
          end
        end

        self.ls_files = Hook.shell!("git ls-tree --full-tree --name-only -r HEAD").split("\n")
      },

      "pre-commit" => proc {
        files_with_status = Hook.shell!("git diff --name-status --cached").split("\n")

        self.files_changed = []
        self.file_contents = {}
        self.file_diffs = {}
        self.commits = []

        files_with_status.each do |f|
          status, file_changed = f.scan(/([ACDMRTUXB])\s+(\S+)$/).flatten
          self.files_changed << file_changed
         
          file_diffs[file_changed] = Hook.shell!("git diff --cached -- #{file_changed}")          
          file_contents[file_changed] = status == "D"? "": Hook.shell!("git show :#{file_changed}")
        end

        self.ls_files = Hook.shell!("git ls-files").split("\n")
      },

      "post-commit" => proc {
        last_commit_files = Hook.shell!("git log --oneline --name-status -1")
        # Split, cut off leading line to get actual files with status
        files_with_status = last_commit_files.split("\n")[1..-1]

        self.files_changed = []
        self.commits = [ Hook.shell!("git log -n 1 --pretty=format:%H").chomp ]
        self.file_contents = {}
        self.file_diffs = {}

        files_with_status.each do |f|
          status, file_changed = f.scan(/([ACDMRTUXB])\s+(\S+)$/).flatten
          self.files_changed << file_changed
 
          file_diffs[file_changed] = Hook.shell!("git log --oneline -p HEAD~..HEAD -- #{file_changed}")
          file_contents[file_changed] = status == "D"? "": Hook.shell!("git show :#{file_changed}")
        end

        self.ls_files = Hook.shell!("git ls-files").split("\n")
      },

      "commit-msg" => proc {
        files_with_status = Hook.shell!("git diff --name-status --cached").split("\n")
       
        self.files_changed = []
        self.file_contents = {}
        self.file_diffs = {}
        self.commits = []

        files_with_status.each do |f|
          status, file_changed = f.scan(/([ACDMRTUXB])\s+(\S+)$/).flatten
          self.files_changed << file_changed

          file_diffs[file_changed] = Hook.shell!("git diff --cached -- #{file_changed}")
          file_contents[file_changed] = status == "D"? "": Hook.shell!("git show :#{file_changed}")
       end

        self.ls_files = Hook.shell!("git ls-files").split("\n")
        self.commit_message = File.read(ARGV[0])
      }
    }
    HOOK_TYPE_SETUP["post-receive"] = HOOK_TYPE_SETUP["pre-receive"]

    def self.initial_setup
      return if @run_from

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

      if hook_specs.empty?
        return @registered_hooks.values.inject([], &:+)
      end

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
      if @has_run
        STDERR.puts <<ERR
In this version, you can't call .run more than once.  For now, please
register your hooks individually and then call .run with no args, or
else call .run with both as arguments.  This may be fixed in a future
version.  Sorry!
ERR
        exit 1
      end
      @has_run = true

      initial_setup

      run_as_specific_githook

      # By default, run all hooks
      hooks_to_run = get_hooks_to_run(hook_specs.flatten)

      failed_hooks = []
      val = nil
      hooks_to_run.each do |hook|
        begin
          hook.setup { val = hook.check }  # Re-init each time, just in case
          failed_hooks.push(hook) unless val
        rescue
          # Failed.  Return non-zero if that makes a difference.
          STDERR.puts "Hook #{hook.inspect} raised exception: #{$!.inspect}!\n#{$!.backtrace.join("\n")}"
          failed_hooks.push hook
        end
      end

      if CAN_FAIL_HOOKS.include?(@run_as_hook) && failed_hooks.size > 0
        STDERR.puts "Hooks failed: #{failed_hooks}"
        STDERR.puts "Exiting!"
        exit 1
      end
    end

    def self.run_as_specific_githook
      return if @run_as_hook  # Already did this

      self.initial_setup  # Might have already done this

      if ARGV.include? "--hook"
        idx = ARGV.find_index "--hook"
        @run_as_hook = ARGV[idx + 1]
        2.times { ARGV.delete_at(idx) }
      else
        @run_as_hook = HOOK_NAMES.detect { |hook| @run_as.include?(hook) }
      end

      unless @run_as_hook
        STDERR.puts "Name #{@run_as.inspect} doesn't include " +
          "any of: #{HOOK_NAMES.inspect}"
        exit 1
      end

      unless HOOK_TYPE_SETUP[@run_as_hook]
        STDERR.puts "No setup defined for hook type #{@run_as_hook.inspect}!"
        exit 1
      end
      self.instance_eval(&HOOK_TYPE_SETUP[@run_as_hook])
    end

    def self.register(hook)
      @registered_hooks ||= {}
      @registered_hooks[hook.class.name] ||= []
      @registered_hooks[hook.class.name].push hook

      # Figure out when to set this up...
      #at_exit do
      #  unless RubyGitHooks::Hook.has_run
      #    STDERR.puts "No call to RubyGitHooks.run happened, so no hooks ran!"
      #  end
      #end
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

  # Forward these calls from RubyGitHooks to RubyGitHooks::Hook
  class << self
    [ :run, :register, :run_as ].each do |method|
      define_method(method) do |*args, &block|
        RubyGitHooks::Hook.send(method, *args, &block)
      end
    end
  end

  def self.shebang
    ENV['RUBYGITHOOKS_SHEBANG']
  end

  def self.current_hook
    RubyGitHooks::Hook.run_as_specific_githook
    RubyGitHooks::Hook.run_as_hook
  end
end

# Default to /usr/bin/env ruby for shebang line
ENV['RUBYGITHOOKS_SHEBANG'] ||= "#!/usr/bin/env ruby"
