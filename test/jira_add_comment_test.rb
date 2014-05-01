# encoding: UTF-8
# Copyright (C) 2013-2014 OL2, Inc. See LICENSE.txt for details.

require "test_helper"
require "ruby_git_hooks/jira_add_comment"

require "minitest/autorun"
require "rest-client"

class JiraCommentAddHookTest < HookTestCase
  REPOS_DIR = File.expand_path File.join(File.dirname(__FILE__), "repos")

  def setup
    # NOTE- we can't just register a hook and do the commit and push
    # for these tests because we need to mock the calls to
    # RestClient to access Jira and the RubyGitHooks run in a separate process
    # so the mocking won't work.

    # Still create the repos and do the commits in order to get valid commit IDs
    # for when we do the check directly

    # Empty out the test repos dir
    Hook.shell! "rm -rf #{File.join(REPOS_DIR, "*")}"
    # Create local parent and child repos with a single shared commit
    Dir.chdir REPOS_DIR

    new_bare_repo
    clone_repo
    new_commit "child_repo", "README"
    git_push
    # add_hook("parent_repo.git", "post-receive", TEST_HOOK)   # can't do this
    @hook = JiraCommentAddHook.new "host" => "jira.example.com",
                                       "username" => "user", "password" => "password"
  end

  def fake_hook_check(msg = "Commit message", with_branch_merge = false)
    new_commit("child_repo", "file.txt","Contents",  msg)
    stub(@hook).commit_message { msg }
    sha = last_commit_sha("child_repo")
    hook_refs = {sha => ["refs/heads/master"]}   # it's always the master branch
    if with_branch_merge
      git_create_and_checkout_branch("child_repo", "B1")
      new_commit("child_repo", "file2.txt","Contents",  "B1 commit\n(#{msg})")
      sha2 = last_commit_sha("child_repo")

      git_checkout("child_repo", "master")
      git_merge("child_repo", "B1", "Merge Branch B1\n(#{msg})")
      merge_sha = last_commit_sha("child_repo")

      hook_refs[sha2] = ["refs/heads/master","refs/heads/B1"]
      hook_refs[merge_sha] = ["refs/heads/master"]
    end

    stub(@hook).commit_ref_map{ hook_refs  }
    stub(@hook).commits{hook_refs.keys}

    Dir.chdir("child_repo") do
      @hook.check
    end
  end

  def test_no_reference_to_jira

    dont_allow(JiraCommentAddHook).get_comment_content    # check that no comment text is prepared
                                                          # because there are no tickets
    fake_hook_check("No reference to Jira")
    # will raise error if get_comment_content is called
  end

  def test_malformed_reference
    dont_allow(JiraCommentAddHook).get_comment_content   # check that no comment text is prepared
                                                         # because there are no tickets
    fake_hook_check( "Incorrect reference to JiraJIRA-123" )
    # will raise error if get_comment_content is called
  end


  def test_bad_reference
    dont_allow(JiraCommentAddHook).add_comment   # check that no comments are added
                                                 # because there are no valid tickets
    mock(RestClient).get("https://user:password@jira.example.com/rest/api/latest/issue/BAD-234") do
      exc = RestClient::Exception.new
      mock(exc).http_code.at_least(1) { 404 }
      raise exc
    end

    fake_hook_check("Message with BAD-234 reference to Jira" )

    # will raise error if add_comment is called

  end


  def test_good_reference
    mock(RestClient).get("https://user:password@jira.example.com/rest/api/latest/issue/GOOD-234") { <<JSON }
{ "fields": { "status": { "name": "Open" } } }
JSON

    mock(RestClient).post.with_any_args {<<JSON }      # more complicated to check the args, just be sure it's called.
{ "fields": { "status": { "name": "Open" } } }
JSON
    git_tag("child_repo", "0.1")
    fake_hook_check("Message with GOOD-234 reference to Jira" )

    # as long as the mocked RestClient calls happen, we succeeded
    # would be better if we had a way to check if the tag is in the message
    # but at least we'll make sure it doesn't fail.
  end

  def test_same_good_reference_twice
    mock(RestClient).get("https://user:password@jira.example.com/rest/api/latest/issue/GOOD-234") { <<JSON }
{ "fields": { "status": { "name": "Open" } } }
JSON

    mock(RestClient).post.with_any_args {<<JSON }      # more complicated to check the args, just be sure it's called.
{ "fields": { "status": { "name": "Open" } } }
JSON
    git_tag("child_repo", "0.1")
    fake_hook_check("Message with GOOD-234 reference to Jira and another GOOD-234" )

    # as long as the mocked RestClient calls happen, we succeeded
    # would be better if we had a way to check if the tag is in the message
    # but at least we'll make sure it doesn't fail.
  end

  def test_good_reference_with_description

    mock(RestClient).get("https://user:password@jira.example.com/rest/api/latest/issue/GOOD-234") { <<JSON }
{ "fields": { "status": { "name": "Open" } } }
JSON

    mock(RestClient).post.with_any_args {<<JSON }      # more complicated to check the args, just be sure it's called.
{ "fields": { "status": { "name": "Open" } } }
JSON
    # add a tag so describe works

    fake_hook_check("Message with GOOD-234 reference to Jira" )
  end

  def test_good_reference_with_long_message

    mock(RestClient).get("https://user:password@jira.example.com/rest/api/latest/issue/GOOD-234") { <<JSON }
{ "fields": { "status": { "name": "Open" } } }
JSON

    mock(RestClient).post.with_any_args {<<JSON }      # more complicated to check the args, just be sure it's called.
{ "fields": { "status": { "name": "Open" } } }
JSON

    fake_hook_check("Message with GOOD-234 reference to Jira\n\nWhat if it can't handle unicode like ©?\n(Good, it can!)" )
  end

  def test_good_ref_with_merge
    stub(RestClient).get("https://user:password@jira.example.com/rest/api/latest/issue/GOOD-234") { <<JSON }
{ "fields": { "status": { "name": "Open" } } }
JSON

    stub(RestClient).post.with_any_args {<<JSON }      # more complicated to check the args, just be sure it's called.
{ "fields": { "status": { "name": "Open" } } }
JSON
    #  look at output to see what gets generated for message
    puts "***** STARTING MERGE REF CHECK *****"
    fake_hook_check("Message with GOOD-234 reference to Jira" , true)
  end


  def test_multiple_references_with_good
    mock(RestClient).get("https://user:password@jira.example.com/rest/api/latest/issue/GOOD-234") { <<JSON }
{ "fields": { "status": { "name": "Open" } } }
JSON
    mock(RestClient).get("https://user:password@jira.example.com/rest/api/latest/issue/BAD-456") do
      exc = RestClient::Exception.new
      mock(exc).http_code.at_least(1) { 404 }
      raise exc
    end
    mock(RestClient).get("https://user:password@jira.example.com/rest/api/latest/issue/NOT-123") do
      exc = RestClient::Exception.new
      mock(exc).http_code.at_least(1) { 404 }
      raise exc
    end
    mock(RestClient).get("https://user:password@jira.example.com/rest/api/latest/issue/CLOSE-123") { <<JSON }
{ "fields": { "status": { "name": "Closed" } } }
JSON

mock(RestClient).post.with_any_args {<<JSON }    # more complicated to check the args, just be sure it's called.
  { "fields": { "status": { "name": "Open" } } }
JSON

    fake_hook_check("Message with CLOSE-123 BAD-456 GOOD-234 NOT-123 reference to Jira" )


  end

  def test_multiple_references_none_good
    dont_allow(JiraCommentAddHook).add_comment   # check that no comments are added
                                                 # because there are no valid tickets
    mock(RestClient).get("https://user:password@jira.example.com/rest/api/latest/issue/BAD-456") do
      exc = RestClient::Exception.new
      mock(exc).http_code.at_least(1) { 404 }
      raise exc
    end
    mock(RestClient).get("https://user:password@jira.example.com/rest/api/latest/issue/CLOSE-123") { <<JSON }
{ "fields": { "status": { "name": "Closed" } } }
JSON
    fake_hook_check("Message with CLOSE-123 BAD-456 reference to Jira" )
  end


  def test_closed_ok_when_not_checking
    @hook = JiraCommentAddHook.new "check_status" => false, "host" => "jira.example.com",
                                   "username" => "user", "password" => "password"

    mock(RestClient).get("https://user:password@jira.example.com/rest/api/latest/issue/CLOSE-123") { <<JSON }
{ "fields": { "status": { "name": "Closed" } } }
JSON
    mock(RestClient).post.with_any_args {<<JSON }    # more complicated to check the args, just be sure it's called.
  { "fields": { "status": { "name": "Open" } } }
JSON

    fake_hook_check("Message with CLOSE-123 don't check if closed reference to Jira" )


  end





end
