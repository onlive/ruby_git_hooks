# Copyright (C) 2013 OL2, Inc. See LICENSE.txt for details.

require "ruby_git_hooks"

# This hook adds a watermark to the end of commit message so that we
# know the hooks have been run.  It should be run as the last
# commit-msg hook so it changes the message immediately before the
# commit is accepted and other hooks can't remove the watermark
# afterward.

class AddWatermarkCommitHook < RubyGitHooks::Hook
  
  def initialize(mark = "\u00a0")
    @watermark = mark
  end

  def check
    if !commit_message_file
      STDERR.puts "Warning: Watermark hook must be run as commit-msg only"
      return true  # don't actually cause commit to fail
    end
    
    File.open(commit_message_file, 'a') {|f| f.write(@watermark)}
    return true
  end

end
