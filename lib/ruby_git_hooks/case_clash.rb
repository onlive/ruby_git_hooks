# Copyright (C) 2013 OL2, Inc. See LICENSE.txt for details.

require "ruby_git_hooks"

# This hook checks whether a similar file exists with the same name
# except for uppercase/lowercase.  It's useful when Mac OS and Unix
# people need to coexist in a single Git repository.  You can be sure
# that the Linux people can't check in files that the Mac people can
# neither see nor delete.

class CaseClashHook < RubyGitHooks::Hook
  def check
    downcase_hash = {}

    ls_files.map(&:strip).each do |filename|
      downcase_hash[filename.downcase] ||= []
      downcase_hash[filename.downcase].push filename
    end

    okay = true
    downcase_hash.each do |_, filenames|
      if filenames.length > 1
        okay = false
        STDERR.puts "Duplicate-except-case files detected: #{filenames.inspect}"
      end
    end

    okay
  end
end
