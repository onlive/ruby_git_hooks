# Copyright (C) 2013 OL2, Inc. See LICENSE.txt for details.

require "ruby_git_hooks"

# This hook checks the size of each individual file against a
# configurable maximum size.  Once a huge file is in your git history
# it can't be fully removed without rewriting history, so you're
# usually better off preventing them in the first place.

class MaxFileSizeHook < RubyGitHooks::Hook
  DEFAULT_MAX_FILE_SIZE = 10*1024*1024;
  VERBOSE = false

  def initialize(max_size = DEFAULT_MAX_FILE_SIZE)
    @max_file_size = max_size
  end

  def check
    STDERR.puts "Checking, max file size: #{@max_file_size}" if VERBOSE
    okay = true
    file_contents.each do |name, file|
      STDERR.puts "File length: #{file.length}" if VERBOSE
      if file.length > @max_file_size
        okay = false
        STDERR.puts "File #{name} exceeds maximum allowed size!"
      end
    end

    okay
  end
end

