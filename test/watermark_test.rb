# coding: utf-8
require "test_helper"

require "minitest/autorun"

class AddWatermarkHookTest < HookTestCase
  REPOS_DIR = File.expand_path File.join(File.dirname(__FILE__), "repos")
  FAKE_CURL = File.expand_path File.join(File.dirname(__FILE__), "fake_curl")
  TEST_HOOK_BODY = <<TEST
#{RubyGitHooks.shebang}
require "ruby_git_hooks/watermark"

RubyGitHooks.run AddWatermarkCommitHook.new("WATERMARK")
TEST

  def setup
    # Empty out the test repos dir
    Hook.shell! "rm -rf #{File.join(REPOS_DIR, "*")}"

    # Create local parent and child repos with a single shared commit
    Dir.chdir REPOS_DIR

    new_bare_repo
    clone_repo
    new_commit "child_repo", "README"
    git_push
  end

  def test_commit_has_watermark
    add_hook("child_repo", "commit-msg", TEST_HOOK_BODY)

    # This should succeed
    new_commit "child_repo", "test2", "GoodContents", "Commit message"
    msg = last_commit_message ("child_repo")
    assert msg =~/WATERMARK/
  end


end
