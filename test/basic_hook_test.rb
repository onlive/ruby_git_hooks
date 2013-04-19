require "test_helper"

require "fileutils"
require "minitest/autorun"

class BasicHookTest < HookTestCase
  REPOS_DIR = File.expand_path File.join(File.dirname(__FILE__), "repos")

  def setup
    # Empty out the test repos dir
    Hook.shell! "rm -rf #{File.join(REPOS_DIR, "*")}"

    # Create local parent and child repos with a single shared commit
    Dir.chdir REPOS_DIR

    new_bare_repo
    clone_repo
    Hook.shell! "cd child_repo && echo Bob > README && git add README && git commit -m 'README' && git push"
  end

  def test_simple_pre_commit
    pch_test_path = File.join(REPOS_DIR, "pch_test_file")
    add_hook("child_repo", "pre-commit", <<HOOK)
#!/usr/bin/env ruby
require "ruby_git_hooks"

class TestHook < RubyGitHooks::Hook
  def check
    File.open("#{pch_test_path}", "w") do |f|
      f.puts files_changed.inspect, file_contents.inspect
    end
    puts "Test hook runs!"
    true
  end
end

RubyGitHooks.run TestHook.new
HOOK

    new_single_file_commit "child_repo"

    assert File.exist?(pch_test_path), "Test pre-commit hook didn't run!"
  end

  #def test_simple_pre_receive
  #  assert true
  #end

end
