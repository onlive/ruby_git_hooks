require "test_helper"

require "minitest/autorun"

class BasicHookTest < HookTestCase
  REPOS_DIR = File.expand_path File.join(File.dirname(__FILE__), "repos")
  TEST_PATH = File.join(REPOS_DIR, "hook_test_file")
  TEST_HOOK_BODY = <<HOOK
#{RubyGitHooks.shebang}
require "ruby_git_hooks"

class TestHook < RubyGitHooks::Hook
  def check
    File.open("#{TEST_PATH}", "w") do |f|
      f.puts files_changed.inspect, file_contents.inspect
    end
    puts "Test hook runs!"
    true
  end
end

RubyGitHooks.run TestHook.new
HOOK
  def setup
    # Empty out the test repos dir
    Hook.shell! "rm -rf #{File.join(REPOS_DIR, "*")}"

    # Create local parent and child repos with a single shared commit
    Dir.chdir REPOS_DIR

    new_bare_repo
    clone_repo
    new_single_file_commit
    git_push
  end

  def test_simple_pre_commit
    add_hook("child_repo", "pre-commit", TEST_HOOK_BODY)

    new_single_file_commit "child_repo"

    assert File.exist?(TEST_PATH), "Test pre-commit hook didn't run!"
    assert File.read(TEST_PATH).include?("Single-file commit"),
      "No file contents reached pre-commit hook!"
  end

  def test_simple_pre_receive
    add_hook("parent_repo.git", "pre-receive", TEST_HOOK_BODY)

    new_single_file_commit "child_repo"
    git_push("child_repo")

    assert File.exist?(TEST_PATH), "Test pre-receive hook didn't run!"
    assert File.read(TEST_PATH).include?("Single-file commit"),
      "No file contents reached pre-receive hook!"
  end

end
