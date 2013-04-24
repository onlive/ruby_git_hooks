# coding: utf-8
require "test_helper"

require "minitest/autorun"

class NonAsciiHookTest < HookTestCase
  REPOS_DIR = File.expand_path File.join(File.dirname(__FILE__), "repos")
  FAKE_CURL = File.expand_path File.join(File.dirname(__FILE__), "fake_curl")
  TEST_HOOK_BODY = <<TEST
#{RubyGitHooks.shebang}
require "ruby_git_hooks/non_ascii"

RubyGitHooks.run NonAsciiCharactersCheckHook.new
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

  def test_non_ascii_commit_msg
    add_hook("child_repo", "commit-msg", TEST_HOOK_BODY)

    assert_raises RuntimeError do
      new_commit "child_repo", "test1", "Contents", "Hello this a mixed string Â© that I made.\nнельзя писать в коммит сообщение по русски"
    end

    # This should succeed
    new_commit "child_repo", "test2", "GoodContents", "Nice and warm non-ascii message"

  end

  #def test_case_clash_pre_commit
  #  add_hook("parent_repo.git", "pre-receive", TEST_HOOK_BODY)
  #end

end
