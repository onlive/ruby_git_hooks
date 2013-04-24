require "test_helper"

require "minitest/autorun"

class JiraReferenceCheckHookTest < HookTestCase
  REPOS_DIR = File.expand_path File.join(File.dirname(__FILE__), "repos")
  FAKE_CURL = File.expand_path File.join(File.dirname(__FILE__), "fake_curl")
  TEST_HOOK_BODY = <<TEST
#{RubyGitHooks.shebang}
require "ruby_git_hooks/jira_ref_check"

RubyGitHooks.run JiraReferenceCheckHook.new(
  "protocol" => "https",
  "jira_uri" => "jira.onlive.com/test",
  "username" => "user",
  "password" => "password",
  "curl" => "#{FAKE_CURL}")
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

  def test_jira_ref_commit_msg
    add_hook("child_repo", "commit-msg", TEST_HOOK_BODY)

    assert_raises RuntimeError do
      new_commit "child_repo", "test1", "Contents", "No reference to Jira"
    end

    assert_raises RuntimeError do
      new_commit "child_repo", "test2", "Contents", "Incorrect reference to JiraJIRA-123"
    end

    assert_raises RuntimeError do
      new_commit "child_repo", "test3", "Contents", "Message with BAD-234 reference to Jira"
    end

    new_commit "child_repo", "test4", "GoodContents", "Message with GOOD-234 reference to Jira"

  end

  #def test_case_clash_pre_commit
  #  add_hook("parent_repo.git", "pre-receive", TEST_HOOK_BODY)
  #end

end
