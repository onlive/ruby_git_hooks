require "test_helper"
require "ruby_git_hooks/jira_ref_check"

require "minitest/autorun"
require "rest-client"

class JiraReferenceCheckHookTest < HookTestCase
  def setup
    @hook = JiraReferenceCheckHook.new "host" => "jira.onlive.com",
      "username" => "user", "password" => "password"
  end

  def test_no_reference_to_jira
    mock(@hook).commit_message.at_least(1) { "No reference to Jira" }

    assert_equal false, @hook.check
  end

  def test_malformed_reference
    mock(@hook).commit_message.at_least(1) { "Incorrect reference to JiraJIRA-123" }

    assert_equal false, @hook.check
  end

  def test_bad_reference
    mock(@hook).commit_message.at_least(1) { "Message with BAD-234 reference to Jira" }
    mock(RestClient).get("https://user:password@jira.onlive.com/rest/api/latest/issue/BAD-234") do
      exc = RestClient::Exception.new
      mock(exc).http_code.at_least(1) { 404 }
      raise exc
    end

    assert_equal false, @hook.check
  end

  def test_good_reference
    mock(@hook).commit_message.at_least(1) { "Message with GOOD-234 reference to Jira" }
    mock(RestClient).get("https://user:password@jira.onlive.com/rest/api/latest/issue/GOOD-234") { <<JSON }
{ "fields": { "status": { "name": "Open" } } }
JSON

    assert_equal true, @hook.check
  end

end
