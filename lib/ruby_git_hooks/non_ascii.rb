# Copyright (C) 2013 OL2, Inc. Some Rights Reserved. See LICENSE.txt for details.

require "ruby_git_hooks"

# Check that commit message contains only ASCII characters
class NonAsciiCharactersCheckHook < RubyGitHooks::Hook
  Hook = RubyGitHooks::Hook

  def initialize(options = {})
  end

  def check
    if !commit_message || commit_message.length == 0
      STDERR.puts "Commit message is missing or empty!"
      return false
    end

    # Brute force approach. I didn't find any clever way to check for non-ascii
    # using string encoder tricks
    count = 0
    valid_control_chars = [13, 10, 9]
    commit_message.each_byte do |b|
      if b > 127 || (b < 32 && !valid_control_chars.include?(b))
        count = count + 1
      end
    end
    if count > 0
      STDERR.puts "Commit message has #{count} non-ASCII characters"
    end
    return count == 0 ? true : false
  end
end
