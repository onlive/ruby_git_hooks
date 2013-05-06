require "test_helper"

require "minitest/autorun"

class CaseClashHookTest < HookTestCase
  REPOS_DIR = File.expand_path File.join(File.dirname(__FILE__), "repos")
  TEST_HOOK_BODY = <<TEST
#{RubyGitHooks.shebang}
require "ruby_git_hooks/case_clash"

RubyGitHooks.run CaseClashHook.new
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

  def test_case_clash_pre_commit
    add_hook("child_repo", "pre-commit", TEST_HOOK_BODY)

    new_commit "child_repo", "CaseClashFile1"
    case1_sha = last_commit_sha
    rewind_one_commit

    new_commit "child_repo", "CASECLASHFILE1"
    case2_sha = last_commit_sha

    # Cherry-pick new content into place -- this means both files.
    Hook.shell!("cd child_repo && git cherry-pick #{case1_sha}")
    case_both = last_commit_sha

    rewind_one_commit

    # Soft-reset so content is still present
    Hook.shell!("cd child_repo && git reset #{case_both}")

    # Should reject w/ pre-commit hook
    # TODO: check error more specifically
    assert_raises RuntimeError do
      Hook.shell!("cd child_repo && git commit -m \"Message\"")
    end
  end

  #def test_case_clash_pre_receive
  #  add_hook("parent_repo.git", "pre-receive", TEST_HOOK_BODY)
  #end

end
