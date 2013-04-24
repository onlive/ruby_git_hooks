require "ruby_git_hooks"

# Check that commit message has one or more valid Jira ticket references
class JiraReferenceCheckHook < RubyGitHooks::Hook
  Hook = RubyGitHooks::Hook

  JIRA_TICKET_REGEXP = /(?:\s|^)[A-Z]{3,10}-\d{1,6}(?:\s|$)/

  OPTIONS = [ "protocol", "jira_uri", "curl", "username", "password" ]

  def initialize(options = {})
    bad_options = options.keys - OPTIONS
    raise "JiraReferenceCheck created with unrecognized options: " +
              "#{bad_options.inspect}!" if bad_options.size > 0

    if !options.has_key?("username") || !options.has_key?("password")
      raise "You must provide Jira server user name and password in options"
    end

    @options = options
    @options["curl"] ||= "curl"
    @options["protocol"] ||= "https"
    @options["jira_uri"] ||= "jira.onlive.com/rest/api/latest/issue"
    @options["curl_options"] ||= {}
  end

  def build_uri(ticket)
     "#{@options['protocol']}://#{@options['username']}:#{@options['password']}@#{@options['jira_uri']}/#{ticket}"
  end

  def check
    if commit_message.length == 0
      STDERR.puts "Commit message is zero length"
      return false
    end

    jira_tickets = commit_message.scan(JIRA_TICKET_REGEXP).map(&:strip)
    if jira_tickets.length == 0
      STDERR.puts "Commit message must refer to a jira ticket"
      return false
    end

    ok = true
    jira_tickets.each do |ticket|
      res = Hook.shell!("#{@options['curl']}", "-I", "#{build_uri(ticket)}")
      if ! (res =~ /200 OK/)
        STDERR.puts "Found reference to invalid Jira ticket #{ticket}"
        ok = false
      end
    end
    ok

  end
end
