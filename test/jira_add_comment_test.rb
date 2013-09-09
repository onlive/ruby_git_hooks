# Copyright (C) 2013 OL2, Inc. Some Rights Reserved. See LICENSE.txt for details.

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
    @hook = JiraCommentAddHook.new "host" => "jira.onlive.com",
                                       "username" => "user", "password" => "password"
  end

  def fake_hook_check(msg = "Commit message")
    new_commit("child_repo", "file.txt","Contents",  msg)
    stub(@hook).commit_message { msg }
    sha = last_commit_sha("child_repo")
    stub(@hook).commits{[sha]}
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
    mock(RestClient).get("https://user:password@jira.onlive.com/rest/api/latest/issue/BAD-234") do
      exc = RestClient::Exception.new
      mock(exc).http_code.at_least(1) { 404 }
      raise exc
    end

    fake_hook_check("Message with BAD-234 reference to Jira" )

    # will raise error if add_comment is called

  end


  def test_good_reference
    mock(RestClient).get("https://user:password@jira.onlive.com/rest/api/latest/issue/GOOD-234") { <<JSON }
{ "fields": { "status": { "name": "Open" } } }
JSON

    mock(RestClient).post.with_any_args {<<JSON }      # more complicated to check the args, just be sure it's called.
{ "fields": { "status": { "name": "Open" } } }
JSON

    fake_hook_check("Message with GOOD-234 reference to Jira" )

    # as long as the mocked RestClient calls happen, we succeeded
  end


  def test_multiple_references_with_good
    mock(RestClient).get("https://user:password@jira.onlive.com/rest/api/latest/issue/GOOD-234") { <<JSON }
{ "fields": { "status": { "name": "Open" } } }
JSON
    mock(RestClient).get("https://user:password@jira.onlive.com/rest/api/latest/issue/BAD-456") do
      exc = RestClient::Exception.new
      mock(exc).http_code.at_least(1) { 404 }
      raise exc
    end
    mock(RestClient).get("https://user:password@jira.onlive.com/rest/api/latest/issue/NOT-123") do
      exc = RestClient::Exception.new
      mock(exc).http_code.at_least(1) { 404 }
      raise exc
    end
    mock(RestClient).get("https://user:password@jira.onlive.com/rest/api/latest/issue/CLOSE-123") { <<JSON }
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
    mock(RestClient).get("https://user:password@jira.onlive.com/rest/api/latest/issue/BAD-456") do
      exc = RestClient::Exception.new
      mock(exc).http_code.at_least(1) { 404 }
      raise exc
    end
    mock(RestClient).get("https://user:password@jira.onlive.com/rest/api/latest/issue/CLOSE-123") { <<JSON }
{ "fields": { "status": { "name": "Closed" } } }
JSON
    fake_hook_check("Message with CLOSE-123 BAD-456 reference to Jira" )
  end

  def test_closed_ok_when_not_checking
    @hook = JiraCommentAddHook.new "host" => "jira.onlive.com",
                                   "username" => "user", "password" => "password",
                                   "check_status" => true

    mock(RestClient).get("https://user:password@jira.onlive.com/rest/api/latest/issue/CLOSE-123") { <<JSON }
{ "fields": { "status": { "name": "Closed" } } }
JSON
    fake_hook_check("Message with CLOSE-123 BAD-456 reference to Jira" )


  end


end
