# Copyright (C) 2013 OL2, Inc. See LICENSE.txt for details.

require "ruby_git_hooks"

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
