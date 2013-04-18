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

    HOOK_TYPE_SETUP = {

      # Pre-receive gets no args, but STDIN with a list of changes.
      "pre-receive" => proc {
        changes = []
        STDIN.each_line do |line|
          base, commit, ref = line.strip.split
          changes.push [base, commit, ref]
        end
        Hook.files_changed = []
        Hook.file_contents = {}
        Hook.file_diffs = {}
        changes.each do |base, commit, ref|
          files_changed = `git diff --name-only #{base}..#{commit}`
          file_contents = {}
          file_diffs = {}
          files_changed.each do |file_changed|
            file_contents[file_changed] = `git show #{commit}:#{file_changed}`
            file_diffs[file_changed] = `git diff #{commit} #{file_changed}`
          end

          Hook.files_changed ||= files_changed
          Hook.file_contents.merge! file_contents
          Hook.file_diffs.merge! file_diffs
        end

        Hook.ls_files = `git ls-tree --full-tree --name-only -r HEAD`.split("\n")
      },

      "pre-commit" => proc {
        files_changed = `git diff --name-only --cached`.split("\n")
        file_contents = {}
        file_diffs = {}

        files_changed.each do |file_changed|
          file_diffs[file_changed] = `git diff --cached #{file_changed}`
          file_contents[file_changed] = File.read(file_changed)
        end

        Hook.files_changed = files_changed
        Hook.file_contents = file_contents
        Hook.file_diffs = file_diffs
        Hook.ls_files = `git ls-files`.split("\n")
      },
    }

    def self.initial_setup
      @run_from = Dir.getwd
      @run_as = $0
    end

    def self.setup
      Dir.chdir @run_from do
        yield
      end

    ensure
      # Nothing yet
    end

    def self.run(*hooks_to_run)
      initial_setup

      run_as_specific_hook

      # By default, run all hooks
      hooks_to_run = @registered_hooks.keys if hooks_to_run.empty?

      hooks_to_run.each do |hook|
        unless @registered_hooks[hook]
          STDERR.puts "Can't locate hook #{hook.inspect}!"
          next
        end

        begin
          setup { hook.check }  # Re-init each time, just in case
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

    def self.run_as_specific_hook
      @run_as_hook = HOOK_NAMES.select { |hook| @run_as.include?(hook) }
      unless @run_as_hook
        STDERR.puts "Name #{@run_as.inspect} doesn't include " +
          "any of: #{HOOK_NAMES.inspect}"
        exit 1
      end
      unless HOOK_TYPE_SETUP[@run_as_hook]
        STDERR.puts "No setup defined for hook type #{@run_as_hook}!"
        exit 1
      end
      HOOK_TYPE_SETUP[@run_as_hook].call
    end


    def self.register(hook_name, hook)
      @registered_hooks ||= {}
      @registered_hooks[hook_name] = hook
    end
  end
end
