# Copyright (C) 2013-2014 OL2, Inc. See LICENSE.txt for details.

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

  TEST_HOOK_MULTI = <<HOOK
#{RubyGitHooks.shebang}
require "ruby_git_hooks"

class TestHook < RubyGitHooks::Hook
  def check
    File.open("#{TEST_PATH}", "w") do |f|
      f.puts commit_ref_map.inspect
      f.puts branches_changed.keys
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
    @hook_name ||= "pre-receive"
    add_hook("parent_repo.git", @hook_name, TEST_HOOK_BODY)

    new_single_file_commit "child_repo"

    git_push("child_repo")

    assert File.exist?(TEST_PATH), "Test #{@hook_name} hook didn't run!"

    # file contents not expected to reach pre-receive hook for first push of a branch
   # assert File.read(TEST_PATH).include?("Single-file commit"),  "No file contents reached pre-receive hook!"
  end


  def test_multiple_pre_receive
    @hook_name ||= "pre-receive"
    add_hook("parent_repo.git", @hook_name, TEST_HOOK_MULTI)

    before_commits =  git_revlist_all("child_repo")  # commits already in the repo

    new_single_file_commit "child_repo"

    git_create_and_checkout_branch("child_repo", "B1")
    new_single_file_commit "child_repo"
    git_push_all("child_repo")  # pushes multiple branches

    assert File.exist?(TEST_PATH), "Test pre-receive hook didn't run!"

    commits =  git_revlist_all("child_repo") - before_commits  # will give us all the commits we just made
    contents = File.read(TEST_PATH)
    commits.each do |c|
      assert contents.include?(c), "Missing commit info for #{c} in #{@hook_name} hook!"
    end
    assert contents.include?("B1")
    assert contents.include?("master")
  end

  def test_simple_post_receive
    @hook_name = "post-receive"  # pre and post are the same, but want to test both
    # default to pre but this lets us use the exact same tests.
    test_simple_pre_receive
  end

  def test_multiple_post_receive
    @hook_name = "post-receive"  # pre and post are the same, but want to test both
    # default to pre but this lets us use the exact same tests.
    test_multiple_branch_pre_receive
  end

  def test_delete_post_receive
    @hook_name = "post-receive"  # pre and post are the same, but want to test both
    # default to pre but this lets us use the exact same tests.
    test_pre_receive_with_delete
  end



  def test_multiple_branch_pre_receive
    @hook_name ||= "pre-receive"

    add_hook("parent_repo.git", @hook_name, TEST_HOOK_MULTI)

    before_commits =  git_revlist_all("child_repo")  # commits already in the repo

    new_single_file_commit "child_repo" # commit to master
    git_create_and_checkout_branch("child_repo", "B1")
    new_single_file_commit "child_repo"
    git_create_and_checkout_branch("child_repo", "B2")
    new_single_file_commit "child_repo"
    git_checkout("child_repo", "master")
    new_single_file_commit "child_repo"

    git_push_all("child_repo")  # pushes multiple branches

    commits =  before_commits - git_revlist_all("child_repo")  # will give us all the commits we just made
    contents = File.read(TEST_PATH)
    commits.each do |c|
      assert contents.include?(c), "Missing commit info for #{c} in #{@hook_name} hook!"
    end
    assert contents.include?("B1")
    assert contents.include?("B2")
    assert contents.include?("master")

    # now push a commit to a single existing branch and a new branch
    before_commits =  git_revlist_all("child_repo")  # commits already in the repo

    git_create_and_checkout_branch("child_repo", "B4")  # no commits
    git_checkout("child_repo", "B1")
    new_single_file_commit "child_repo"
    git_create_and_checkout_branch("child_repo", "B3")
    new_single_file_commit "child_repo"

    git_push_all("child_repo")  # pushes multiple branches

    commits =  git_revlist_all("child_repo") - before_commits  # will give us all the commits we just made
    contents = File.read(TEST_PATH)
    commits.each do |c|
      assert contents.include?(c), "Missing commit info for #{c} in pre-receive hook!"
    end
    assert contents.include?("B1")
    assert contents.include?("B3")

    refute contents.include?("B2")
    refute contents.include?("master")

  end

  def test_pre_receive_with_merge_commit
    @hook_name ||= "pre-receive"

    add_hook("parent_repo.git", @hook_name, TEST_HOOK_MULTI)

    # set up master and 2 branches with commits
    # make changes to different files so no merge conflicts
    new_commit("child_repo", "file1.txt","Contents",  "master commit")
    git_create_and_checkout_branch("child_repo", "B1")
    new_commit("child_repo", "file2.txt","Contents",  "B1 commit")
    git_create_and_checkout_branch("child_repo", "B2")
    new_commit("child_repo", "file3.txt","Contents",  "B2 commit")
    git_checkout("child_repo", "master")
    new_commit("child_repo", "file4.txt","Contents",  "master commit")

    git_push_all("child_repo")
    before_commits =  git_revlist_all("child_repo")  # commits already in the repo

    # now do a merge commit
    git_checkout("child_repo", "master")
    git_merge("child_repo", "B1")
    git_push_all("child_repo")

    # make sure none of the before_commits are in the output
    contents = File.read(TEST_PATH)
    before_commits.each do |c|
      refute contents.include?(c), "#{c} shouldn't be processed!"
    end
  end

  def test_pre_receive_ff_merge
    @hook_name ||= "pre-receive"

    add_hook("parent_repo.git", @hook_name, TEST_HOOK_MULTI)

    git_create_and_checkout_branch("child_repo", "B1")
    new_commit("child_repo", "file22.txt","Contents",  "B1 commit")
    new_commit("child_repo", "file23.txt","Contents",  "B1 commit 2")
    git_push_all("child_repo")
    before_commits =  git_revlist_all("child_repo")  # commits already in the repo

    # now a merge ff commit
    # shouldn't be any new commits
    git_checkout("child_repo", "master")
    git_ff_merge("child_repo", "B1")
    after_commits =  git_revlist_all("child_repo")  # commits already in the repo

    git_push_all("child_repo")

    assert_empty(before_commits-after_commits)  # there are no new commits
    contents = File.read(TEST_PATH)
    before_commits.each do |c|
      refute contents.include?(c), "#{c} shouldn't be processed!"
    end

    # should check that branches_changed is accurate
    assert contents.include?("master")


  end


  def test_pre_receive_with_delete
    @hook_name ||= "pre-receive"
    add_hook("parent_repo.git", @hook_name, TEST_HOOK_BODY)

    new_commit "child_repo", "file_to_delete"
    git_push "child_repo"

    git_delete "child_repo", "file_to_delete"
    git_commit "child_repo", "Deleted file_to_delete"
    git_push "child_repo"

    assert File.exist?(TEST_PATH), "Test #{@hook_name} hook didn't run!"
    assert File.read(TEST_PATH).include?('"file_to_delete"=>""'),
      "File deletion did not reach #{@hook_name} hook!"
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
