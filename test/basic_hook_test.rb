require "test_helper"

require "fileutils"
require "minitest/autorun"

class BasicHookTest < MiniTest::Unit::TestCase
  include RubyGitHooks

  REPOS_DIR = File.join(File.dirname(__FILE__), "repos")

  def setup
    # Empty out the test repos dir
    Hook.shell! "rm -rf #{File.join(REPOS_DIR, "*")}"

    # Create local parent and child repos with a single shared commit
    Dir.chdir REPOS_DIR do
      Hook.shell! "mkdir parent_repo.git && cd parent_repo.git && git init --bare"
      Hook.shell! "git clone parent_repo.git child_repo"
      Hook.shell! "cd child_repo && echo Bob > README && git add README && git commit -m 'README' && git push"
    end
  end

  def test_simple_pre_commit
    assert true
  end

  def test_simple_pre_receive
    assert true
  end

end
