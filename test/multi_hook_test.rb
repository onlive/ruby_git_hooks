# Copyright (C) 2013-2014 OL2, Inc. See LICENSE.txt for details.

require "test_helper"

require "minitest/autorun"

class CopyrightCheckHookTest < HookTestCase
  REPOS_DIR = File.expand_path File.join(File.dirname(__FILE__), "repos")
  CURRENT_YEAR = Time.now.strftime("%Y")
  TEST_HOOK_MULTI_REG = <<TEST
#{RubyGitHooks.shebang}
require "ruby_git_hooks/ruby_debug"
require "ruby_git_hooks/copyright_check"

RubyGitHooks.register RubyDebugHook.new
RubyGitHooks.register CopyrightCheckHook.new("no_send" => true)

RubyGitHooks.run
TEST

  TEST_HOOK_MULTI_RUN = <<TEST
#{RubyGitHooks.shebang}
require "ruby_git_hooks/ruby_debug"
require "ruby_git_hooks/copyright_check"

RubyGitHooks.run RubyDebugHook.new,
                 CopyrightCheckHook.new("no_send" => true)
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

  def test_multi_reg_pre_commit
    add_hook("child_repo", "pre-commit", TEST_HOOK_MULTI_REG)

    last_sha = last_commit_sha

    new_commit("child_repo", "myfile.rb", <<FILE_CONTENTS)
# Copyright (C) #{CURRENT_YEAR} YoyoDyne, Inc.  All Rights Reserved.
# No copyright notice, no ruby-debug.  Should be fine.
FILE_CONTENTS

    assert last_sha != last_commit_sha,
      "Multiple pre-commit should accept legal commit."
    last_sha = last_commit_sha  # update

    assert_raises RuntimeError do
      new_commit("child_repo", "myfile.rb", <<FILE_CONTENTS)
# No copyright notice, but no ruby-debug
FILE_CONTENTS
    end

    assert_equal last_sha, last_commit_sha,
      "Multiple pre-commit should refuse illegal commit (1)."

    assert_raises RuntimeError do
      new_commit("child_repo", "myfile.rb", <<FILE_CONTENTS)
# Includes a copyright notice, but has ruby-debug
# Copyright (C) #{CURRENT_YEAR} YoyoDyne, Inc.  All Rights Reserved.
require 'ruby-debug'
FILE_CONTENTS
    end

    assert_equal last_sha, last_commit_sha,
      "Multiple pre-commit should refuse illegal commit (2)."

  end
end
