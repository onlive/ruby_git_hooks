require "ruby_git_hooks"


# Add a watermark to the end of commit message so that we know the hooks have been run.
# Should be run as the last commit-msg hook so it changes the message right before
# the commit is accepted.
class AddWatermarkCommitHook < RubyGitHooks::Hook
  
  def initialize(mark = "\u{00020}")
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
