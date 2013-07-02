require "test_helper"
require "ruby_git_hooks/jira_ref_check"

require "minitest/autorun"

class JiraReferenceCheckHookTest < HookTestCase
  def setup
    @hook = JiraReferenceCheckHook.new
  end

  def test_no_reference_to_jira
    mock(@hook).commit_message.at_least(1) { "No reference to Jira" }

    assert_equal false, @hook.check
  end

  def test_malformed_reference
    mock(@hook).commit_message.at_least(1) { "Incorrect reference to JiraJIRA-123" }

    assert_equal false, @hook.check
  end

  def test_good_reference
    mock(@hook).commit_message.at_least(1) { "Message with GOOD-234 reference to Jira" }

    assert_equal true, @hook.check
  end

  def test_multiple_references_with_good
    mock(@hook).commit_message.at_least(1) { "Message with CLOSE-123 BAD-456 GOOD-234 NOT-123 reference to Jira" }
    assert_equal true, @hook.check

  end
  
end
