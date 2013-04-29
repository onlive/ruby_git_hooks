# Copyright (C) 2013 OL2, Inc.  All Rights Reserved.

require "ruby_git_hooks"

require "rest-client"
require "json"

# TODO: allow passing in list of legal issue statuses

# Check that commit message has one or more valid Jira ticket references
class JiraReferenceCheckHook < RubyGitHooks::Hook
  Hook = RubyGitHooks::Hook

  JIRA_TICKET_REGEXP = /(?:\W|^)[A-Z]{3,10}-\d{1,6}(?:\W|$)/

  OPTIONS = [ "protocol", "host", "username", "password", "api_path" ]

  def initialize(options = {})
    bad_options = options.keys - OPTIONS
    raise "JiraReferenceCheck created with unrecognized options: " +
              "#{bad_options.inspect}!" if bad_options.size > 0

    if !options.has_key?("username") || !options.has_key?("password")
      raise "You must provide Jira server user name and password in options"
    end

    @options = options
    @options["protocol"] ||= "https"
    @options["host"] ||= "jira"
    @options["api_path"] ||= "rest/api/latest/issue"
  end

  def build_uri(ticket)
    "#{@options['protocol']}://#{@options['username']}:#{@options['password']}@#{@options['host']}/#{@options['api_path']}/#{ticket}"
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

    jira_tickets.each do |ticket|
      begin
        resp = RestClient.get build_uri(ticket)
        hash = JSON.parse(resp)

        # Grab the Jira bug status, or fall back to allowing
        # if the format is unexpected.
        status = hash["fields"]["status"]["name"] rescue "open"

        if status.downcase == "closed"
          puts "Issue #{ticket} is closed, not allowing."
        else
          # Bug was open, probably.  Allow it!
          return true
        end
      rescue SocketError
        STDERR.puts "SocketError finding '#{@options["host"]}': #{$!.inspect}"
        STDERR.puts "Is '#{@options["host"]}' the right Jira hostname? "
        STDERR.puts "I'm allowing this in case you're offline, but make sure"
        STDERR.puts "your hostname is right, please!"
        return true
      rescue RestClient::Exception
        if $!.http_code == 401
          STDERR.puts "You're not authorized on this server!"
          STDERR.puts "Please set your username and password correctly."
          break
        elsif $!.http_code == 404
          # Nope, not a valid issue.  Keep trying
        elsif $!.http_code == 407
          STDERR.puts "We don't support proxies to Jira yet!"
          STDERR.puts "I'll give you the benefit of the doubt."
          return true
        elsif $!.http_code >= 500
          STDERR.puts "Jira got a server error."
          STDERR.puts "I'll give you the benefit of the doubt."
          return true
        else
          STDERR.puts "Unexpected HTTP Error: #{$!.http_code}!"
          return false
        end

      rescue
        STDERR.puts "Unexpected exception: #{$!.inspect}!"
        return false

        # TODO: rescue DNS error, allow but nag
      end
    end

    # Getting this far means all tickets were 404s, generally.
    # or only closed JIRA tickets were found (and reported)
    STDERR.puts "Commit message must refer to a valid jira ticket"
    false
  end

  # Do not show password when converting to string
  def to_s
    "<JiraReferenceCheckHook:#{object_id} #{@options.merge("password" => :redacted)}>"
  end

end
