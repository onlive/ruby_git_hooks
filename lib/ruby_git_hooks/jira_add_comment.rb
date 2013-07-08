# Copyright (C) 2013 OL2, Inc.  All Rights Reserved.

require "ruby_git_hooks"

require "rest-client"
require "json"

# TODO: allow passing in list of legal issue statuses

# Called as a post-receive with a list of commits -
# ideally the ruby_git_hooks framework would allow us to get each commit message from them
# but for now we'll do it ourselves.

# Check that commit message has one or more valid Jira ticket references
# and add a comment to the jira ticket(s)
# Won't be able to reject the commit, just continue to the end and check everything
# and report errors

class JiraCommentAddHook < RubyGitHooks::Hook
  Hook = RubyGitHooks::Hook

  JIRA_TICKET_REGEXP = /(?<=\W|^)[A-Z]{3,10}-\d{1,6}(?=\W|$)/

  OPTIONS = [ "protocol", "host", "username", "password", "api_path" ]

  def initialize(options = {})
    bad_options = options.keys - OPTIONS
    raise "JiraCommentAddHook created with unrecognized options: " +
              "#{bad_options.inspect}!" if bad_options.size > 0

    if !options.has_key?("username") || !options.has_key?("password")
      raise "You must provide Jira server user name and password in options"
    end

    @options = options
    @options["protocol"] ||= "https"
    @options["host"] ||= "jira"
    @options["api_path"] ||= "rest/api/latest/issue"
  end

  def build_uri(ticket, command=nil)
    uri = "#{@options['protocol']}://#{@options['username']}:#{@options['password']}@#{@options['host']}/#{@options['api_path']}/#{ticket}"
    uri = "#{uri}/#{command}" if command
    return uri
  end

  def check
    success = true  # assume we're going to get all the way through, but remember if we don't

    if commits.empty? && commit_message && commit_message.length > 0  # we were called pre-commit
      return check_one_commit_message(commit_message)
    end
    # called with a list of commits to check, as post-receive.

    commits.each do |commit|

      options = {}

      commit_message = RubyGitHooks::Hook.shell!("git log #{commit} -1 --pretty=%B")
      puts "Checking #{commit[0..7]} #{commit_message}"
      check_one_commit(commit, commit_message )
    end
    return true #
  end

  # Do not show password when converting to string
  def to_s
    "<JiraCommentAddHook:#{object_id} #{@options.merge("password" => :redacted)}>"
  end

  def check_one_commit(commit, commit_message)

    jira_tickets = commit_message.scan(JIRA_TICKET_REGEXP).map(&:strip)
    if jira_tickets.length == 0
      STDERR.puts "Commit message must refer to a jira ticket"
      return false
    end

    # we know we have to add comments for at least one ticket
    # so build up the options with more info about the commit.

    options = {:commit_message => commit_message}


    success = false
    jira_tickets.each do |ticket|
      valid_ticket = check_for_valid_ticket(ticket)
      if valid_ticket
        add_comment(ticket, options)
        success = true
      end
    end

    STDERR.puts "Commit message must refer to a valid jira ticket" if !success

    return success    # did we find any valid tickets?
  end

  def get_comment_content(ticket, options)

    #  Needs to look like the git equivalent of this
    #/opt/svn/ops rev 37251 committed by andy.lee      (commit shah and committer)
    #http://viewvc.onlive.net/viewvc/ops?rev=37251&view=rev   (github link)
    #NOC-3863 adding check to configs for testing    (commit message and changes)
    #                                   U /trunk/puppet/dist/nagios/nrpe.cfg
    #                                   U /trunk/puppet/dist/nagios/ol_checks.cfg
    # return as a string
    "Commit message: #{options[:commit_message]}"
  end

  def add_comment(ticket, options)
    puts "ADDING COMMENT for ticket #{ticket}"
    return unless ticket == "SYSINT-5366" # just test with a single issue until get the text right.
    uri = build_uri(ticket, "comment")
    puts uri
    data = {"body" => get_comment_content(ticket, options)}
    # Data needs to include a link to the github commit, etc just like the svn

    puts data
    resp = RestClient.post(uri, data.to_json, :content_type => :json, :accept=>:json)
    hash = JSON.parse(resp)
    puts "Added comment #{data}"
  end

  def check_for_valid_ticket(ticket)
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
        return false
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
    false # if we get to this point it's not a valid ticket
  end
end
