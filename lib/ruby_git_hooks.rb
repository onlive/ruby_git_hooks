# Copyright (C) 2013-2014 OL2, Inc. See LICENSE.txt for details.

require "ruby_git_hooks/version"

# This module is the core of the ruby_git_hooks code.  It includes the
# Git commands, the hook types and in general most of the interface.
# README.md is the best overall documentation for this package, but
# this is where you can dig into the lowest-level Git specifics.

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

      # Commit message for current commit
      attr_accessor :commit_message

      # Commit message file for current commit
      attr_accessor :commit_message_file

      # the following are for hooks which involve multiple commits (pre-receive, post-receive):
      # (may be empty in other hooks)
      # All current commits
      attr_accessor :commits

      # refs associated with each commit
      attr_accessor :commit_ref_map

      # branches included in this push
      attr_accessor :branches_changed
    end

    # Instances of Hook delegate these methods to the class methods.
    HOOK_INFO = [ :files_changed, :file_contents, :file_diffs, :ls_files,
                  :commits, :commit_message, :commit_message_file, :commit_ref_map, :branches_changed ]
    HOOK_INFO.each do |info_method|
      define_method(info_method) do |*args, &block|
        Hook.send(info_method, *args, &block)
      end
    end

    HOOK_TYPE_SETUP = {

      # Pre-receive gets no args, but STDIN with a list of changes.
      "pre-receive" => proc {
        def commit_date(c)
          date = Hook.shell!("git log #{c} --pretty=%ct -1").strip.to_i
        end

        changes = []
        STDIN.each_line do |line|
          # STDERR.puts line # for debugging
          base, commit, ref = line.strip.split
          changes.push [base, commit, ref]
        end

        self.branches_changed = {}  # {ref => [base, commit], ref2 => [base, commit]}

        self.commit_ref_map = {}  # commit_ref_map is a list of which new commits are in this push,
        # and which branches they are associated with
        # as {commit1 => [ref1, ref2], commit2 => [ref1]}

        # figure out which commits have already been processed (everything we have seen before)
        exclude_refs = []  # we know we have seen under these refs already
            # includes all branches not referenced in this push
            # and all commits before the base of referenced branches
        all_branches = Hook.shell!("git for-each-ref --format='%(refname)' refs/heads/").split
        changes.each do |base, _ , ref|
          # ref is of the form refs/heads/branch_name
          all_branches.delete(ref)  # we don't want to use the new ref for this branch
          exclude_refs << "^#{base}" unless base =~  /\A0+\z/ # add the old ref for this branch to the exclude list
                # (don't add if it's 0, this is a new branch with no old ref)
        end

        # add the branches which aren't included in this push if any
        all_branches.each { |ref|  exclude_refs << "^#{ref}" }

        self.files_changed = []
        self.file_contents = {}
        self.file_diffs = {}

        changes.each do |base, commit, ref|
          self.branches_changed[ref] = [base, commit]

          # TODO : calculate file_diffs and file_contents PER COMMIT for pre and post receive hooks
          # for now it just does the overall diffs
          if base =~  /\A0+\z/
            # if base is 000 then this is a new branch and we have no easy way know what files were added
            # so for now just don't include files changed in a new branch
            # because really this should be done per commit or at least per branch anyway
            # TODO: we could figure it out based on the branch commit calculations per branch (see below)
            files_with_status = []
          else
            files_with_status = Hook.shell!("git diff --name-status #{base}..#{commit}").split("\n")
          end

          files_with_status.each do |f|
            status, file_changed = f.scan(/([ACDMRTUXB])\s+(\S+)$/).flatten
            self.files_changed << file_changed

            file_diffs[file_changed] = Hook.shell!("git log -p #{commit} -- #{file_changed}")
            begin
              file_contents[file_changed] = status == "D" ? "" : Hook.shell!("git show #{commit}:#{file_changed}")
            rescue
              # weird bug where some repos can't run the git show command even when it's not a deleted file.
              # example: noah-gibbs/barkeep/test/fixtures/text_git_repo  I haven't figured out what's
              # weird about it yet but this fails, so put in a hack for now.  May want to leave this since
              # we'd rather continue without the changes than fail, right?
              file_contents[file_changed] = ""
            end
          end
          
          # calculate which commits are new - exclude any commits that are on any other branches
          # e.g. git rev-list <commit for B3> ^old_B3 ^master ^B2 --
          # (the "--" at the end tells git these are refs NOT file references)
          new_commits = Hook.shell!("git rev-list #{commit} #{exclude_refs.join(' ')} --").split("\n")

          new_commits.each do |one_commit|
            self.commit_ref_map[one_commit] ||= [];
            self.commit_ref_map[one_commit] << ref  # name of the branch associated with this commit
          end
        end

        # we want the list of commits sorted by commit date
        self.commits = self.commit_ref_map.keys.sort{|a,b|commit_date(b) <=> commit_date(a)}

        if !self.commits.empty?
            file_list_revision =  self.commits.first # can't just use HEAD - remote may be on branch with no HEAD
            self.ls_files = Hook.shell!("git ls-tree --full-tree --name-only -r #{file_list_revision}").split("\n")
          # TODO should store ls_files per commit (with status)?
        end
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
 
          file_diffs[file_changed] = Hook.shell!("git log --oneline -p -1 -- #{file_changed}")
          file_contents[file_changed] = status == "D"? "": Hook.shell!("git show :#{file_changed}")
        end

        self.ls_files = Hook.shell!("git ls-files").split("\n")
        self.commit_message = Hook.shell!("git log -1 --pretty=%B")
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
        self.commit_message_file = ARGV[0]
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
        STDERR.puts "Use 'git commit -eF .git/COMMIT_EDITMSG' to restore your commit message" if commit_message
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
