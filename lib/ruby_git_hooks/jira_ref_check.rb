# Copyright (C) 2013 OL2, Inc. See LICENSE.txt for details.

require "ruby_git_hooks"

# This hook checks that the commit message has one or more correctly-formatted
# Jira ticket references.

class JiraReferenceCheckHook < RubyGitHooks::Hook
  Hook = RubyGitHooks::Hook

  JIRA_TICKET_REGEXP = /(?<=\W|^)[A-Z]{2,10}-\d{1,6}(?=\W|$)/
  
  def initialize(options = {})
    # not using options now, but leave this here for backwards compatibility
  end

  def check
    if !commit_message || commit_message.length == 0
      STDERR.puts "Commit message is missing or empty!"
      return false
    end

    jira_tickets = commit_message.scan(JIRA_TICKET_REGEXP).map(&:strip)
    if jira_tickets.length == 0
      STDERR.puts "Commit message must refer to a jira ticket"
      return false
    end

    return true
  end

end
