# TODO: coverage?

# Test local copy first
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), "..", "lib")

require "minitest/pride"
require "ruby_git_hooks"

class HookTestCase < MiniTest::Unit::TestCase
  include RubyGitHooks

  def new_bare_repo(name = "parent_repo.git")
    Hook.shell! "mkdir #{name} && cd #{name} && git init --bare"
  end

  def clone_repo(parent_name = "parent_repo.git", child_name = "child_repo")
    Hook.shell! "git clone #{parent_name} #{child_name}"
  end
end
