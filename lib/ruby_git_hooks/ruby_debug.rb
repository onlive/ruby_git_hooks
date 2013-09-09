# Copyright (C) 2013 OL2, Inc. See LICENSE.txt for details.

require "ruby_git_hooks"

# This exists primarily for testing.  I mean, you can use it and all, but...

class RubyDebugHook < RubyGitHooks::Hook
  def check
    bad_files = []

    file_diffs.each do |file, diff|
      if diff.include? "require 'ruby-debug'"
        bad_files << file
      end
    end

    return true if bad_files.empty?

    puts "You left requires of ruby-debug in the following files:\n"
    puts bad_files.join("\n")

    false
  end
end
