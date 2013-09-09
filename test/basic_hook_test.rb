# Copyright (C) 2013 OL2, Inc. See LICENSE.txt for details.

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

  TEST_HOOK_COMMIT_MSG = <<HOOK
#{RubyGitHooks.shebang}
require "ruby_git_hooks"

class TestHook < RubyGitHooks::Hook
  def check
    File.open("#{TEST_PATH}", "w") do |f|
      f.puts commit_message
    end
    
    puts "Test hook runs!"
    true
  end
end

RubyGitHooks.run TestHook.new
HOOK

  def setup(do_first_commit = true)
    # Empty out the test repos dir
    Hook.shell! "rm -rf #{File.join(REPOS_DIR, "*")}"

    # Create local parent and child repos with a single shared commit
    Dir.chdir REPOS_DIR

    new_bare_repo
    clone_repo
    if do_first_commit
      new_single_file_commit
      git_push
    end
  end

  def test_simple_pre_commit
    add_hook("child_repo", "pre-commit", TEST_HOOK_BODY)

    new_single_file_commit "child_repo"

    assert File.exist?(TEST_PATH), "Test pre-commit hook didn't run!"
    assert File.read(TEST_PATH).include?("Single-file commit"),
      "No file contents reached pre-commit hook!"
  end
  
  def test_pre_commit_with_delete
    add_hook("child_repo", "pre-commit", TEST_HOOK_BODY)
    new_commit "child_repo", "file_to_delete"
    git_delete "child_repo", "file_to_delete"
    git_commit "child_repo", "Deleted file_to_delete"

    assert File.exist?(TEST_PATH), "Test pre-commit hook didn't run!"
    assert File.read(TEST_PATH).include?('"file_to_delete"=>""'),
      "File not deleted properly"
  end

    def test_pre_commit_with_rename
    add_hook("child_repo", "pre-commit", TEST_HOOK_BODY)
    new_commit "child_repo", "file_to_rename"
    git_rename "child_repo", "file_to_rename", "renamed_file"
    new_commit "child_repo", "renamed_file", nil, "Renamed file"

    assert File.exist?(TEST_PATH), "Test pre-commit hook didn't run!"
    assert File.read(TEST_PATH).include?('"file_to_rename"=>""'),
      "File not deleted properly"
  end

  def test_simple_pre_receive
    add_hook("parent_repo.git", "pre-receive", TEST_HOOK_BODY)

    new_single_file_commit "child_repo"
    git_push("child_repo")

    assert File.exist?(TEST_PATH), "Test pre-receive hook didn't run!"
    assert File.read(TEST_PATH).include?("Single-file commit"),
      "No file contents reached pre-receive hook!"
  end


  def test_pre_receive_with_delete
    add_hook("parent_repo.git", "pre-receive", TEST_HOOK_BODY)

    new_commit "child_repo", "file_to_delete"
    git_push "child_repo"

    
    git_delete "child_repo", "file_to_delete"
    git_commit "child_repo", "Deleted file_to_delete"
    git_push "child_repo"


    assert File.exist?(TEST_PATH), "Test pre-receive hook didn't run!"
    assert File.read(TEST_PATH).include?('"file_to_delete"=>""'),
      "File deletion did not reach pre-receive hook!"
  end

  def test_commit_msg
    add_hook("child_repo", "commit-msg", TEST_HOOK_COMMIT_MSG)
    new_commit "child_repo", "my_file", "Commit contents", "This is my commit message"
    assert File.exist?(TEST_PATH), "Test commit-msg hook didn't run!"
    assert File.read(TEST_PATH).include?("This is my commit message"),
      "Commit message did not reach commit-msg hook"
  end

  def test_post_commit_has_commit_msg
    add_hook("child_repo", "post-commit", TEST_HOOK_COMMIT_MSG)
    new_commit "child_repo", "my_file", "Commit contents", "This is my commit message"
    assert File.exist?(TEST_PATH), "Test post-commit hook didn't run!"
    assert File.read(TEST_PATH).include?("This is my commit message"),
      "Commit message did not reach post-commit hook"
  end

  def test_first_pre_receive
      setup(false)  # don't do first commit
      test_simple_pre_receive
  end

end
