# Copyright (C) 2013-2014 OL2, Inc. See LICENSE.txt for details.

require "ruby_git_hooks"
require "ruby_git_hooks/jira_ref_check"

require "rest-client"
require "json"

# This hook adds Jira "commit" comments for your commits.  It is
# called as a post-receive hook with a list of commits - ideally the
# ruby_git_hooks framework would allow us to get each commit message
# from them but for now we'll do it ourselves.

# The hook checks that commit message has one or more valid Jira
# ticket references.  In general we can't always reject a commit.  So
# we continue through the list of commits, check everything and report
# errors.


class JiraCommentAddHook < RubyGitHooks::Hook
  Hook = RubyGitHooks::Hook

  OPTIONS = [ "protocol", "host", "username", "password",
              "api_path", "github", "issues",
              "domain", "from", "subject", "via", "via_options", "intro", "conclusion",
              "no_send", "check_status"]
  VALID_ERROR_TYPES = [:no_jira, :invalid_jira]

  attr_accessor :errors_to_report

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
    @options["github"] ||= "github.com"
    @options["check_status"] = true if !@options.has_key? "check_status"  # don't allow "closed" issues by default

    # options for error emailing

    @options["domain"] ||= "mydomain.com"
    @options["from"] ||= "Jira Jailer <noreply@#{@options["domain"]}>"
    @options["subject"] ||= "Use Jira Ticket Numbers, Please!"
    @options["via"] ||= "no_send"
    @options["via_options"] ||= {}


    @errors_to_report = {}  # listed in hash indexed by user
  end

  def build_uri(ticket, command=nil)
    uri = "#{@options['protocol']}://#{@options['username']}:#{@options['password']}@#{@options['host']}/#{@options['api_path']}/#{ticket}"
    uri = "#{uri}/#{command}" if command
    return uri
  end


  def check
    if commits.empty?
      STDERR.puts "JiraCommentAddHook - need list of commits to process"
    end
    # called with a list of commits to check, as post-receive.
    # consider it a success for now only if all commit checks are successful
    # may cause us to redo some of the checks.
    # but for now it's all or nothing.
    success = true
    commits.reverse_each do |commit|
      commit_message = RubyGitHooks::Hook.shell!("git log #{commit} -1 --pretty=%B").rstrip
      success = false unless check_one_commit(commit, commit_message )
    end

    # send email regarding failed commits
    report_errors
    return success
  end

  # Do not show password when converting to string
  def to_s
    "<JiraCommentAddHook:#{object_id} #{@options.merge("password" => :redacted)}>"
  end


  def repo_remote_path
    remote_urls = RubyGitHooks::Hook.shell!("git remote -v").split
    remote = remote_urls[1]  # ["origin", "git@github.com:my_github_name/ruby_git_hooks.git", "fetch", ...]
    return "" if !remote   # No remote.

    uri = URI.parse(remote) rescue nil
    if uri
      #  "https://github.com/my_github_name/ruby_git_hooks.git "
      uri.to_s.sub(/.git\z/, "")
    else
      # "git@github.com:my_github_name/ruby_git_hooks.git"
      # ?? Can there be a "." in a repo name?
      path = remote[/:([\w\/.-]*)/,1]
      path.sub!(/.git\z/, "") if path
      "#{@options['protocol']}://#{@options['github']}/#{path}"
    end
    # in either case return "https://github.com/my_github_name/ruby_git_hooks"

  end

  def build_commit_uri(commit)
    # like https://github.com/my_github_name/ruby_git_hooks/commit/b067c718a74315224bf88a267a82ac85054cdf6e

    uri = "#{repo_remote_path}/commit/#{commit}"
  end

  def get_commit_branch(commit)
    # get the branch (list) for this commit
    # will usually be a single ref ([refs/heads/branch_name]). but could
    # theoretically be multiple if single commit is on several branches processed at the same time.
    refs = self.commit_ref_map[commit]
    refs ? refs.join(" ") : ""
  end

  def get_comment_content(commit, commit_message)
    #  Needs to look like the git equivalent of this
    #/opt/svn/ops rev 37251 committed by john.doe      (commit shah and committer)
    #http://viewvc.example.com/viewvc/ops?rev=37251&view=rev   (github link)
    #BUG-3863 adding check to configs for testing    (commit message and changes)
    #                                   U /trunk/puppet/dist/nagios/nrpe.cfg
    #                                   U /trunk/puppet/dist/nagios/ol_checks.cfg
    # return as a string
    # revision bac9b85f2 committed by Ruth Helfinstein
    # Fri Jul 12 13:57:28 2013 -0700
    # https://github.com/ruth-helfinstein/ruth-test/commit/bac9b85f2c98ccdba8d25f0b9a6e855cd2535901
    # BUG-5366 commit message
    #
    # M	test.txt

    github_link = build_commit_uri(commit)      # have to do this separately
    branch = "Branch: #{get_commit_branch(commit)}"
    begin
      content = "Revision: %h committed by %cn%nCommit date: %cd%n#{branch}%n#{github_link}%n%n#{commit_message}%n{noformat}"
      text = Hook.shell!("git log #{commit} -1 --name-status --pretty='#{content}'")
      text += "{noformat}" # git log puts changes at the bottom, we need to close the noformat tag for Jira
    rescue
      text = "No commit details available for #{commit}\n#{commit_message}"
    end
    text
  end

  def check_one_commit(commit, commit_message)
    STDERR.puts "Checking #{commit[0..6]} #{commit_message.lines.first}"

    jira_tickets = commit_message.scan(JiraReferenceCheckHook::JIRA_TICKET_REGEXP).map(&:strip)
    if jira_tickets.length == 0
      STDERR.puts ">>Commit message must refer to a jira ticket"
      add_error_to_report(commit, commit_message, "no_jira")
      return false
    end

    # we know we have to add comments for at least one ticket
    # so build up the options with more info about the commit.
    # the comment will be the same in each ticket

    comment_text = get_comment_content(commit, commit_message)

    success = false
    jira_tickets.each do |ticket|
      valid_ticket = check_for_valid_ticket(ticket)
      if valid_ticket
        add_comment(ticket, comment_text)
        success = true
      end
    end
    
    unless success
      STDERR.puts ">>Commit message must refer to a valid jira ticket"
      add_error_to_report(commit, commit_message, "invalid_jira")
    end

    return success    # did we find any valid tickets?
  end



  def add_comment(ticket, comment_text)
    STDERR.puts "ADDING COMMENT for ticket #{ticket}"
    uri = build_uri(ticket, "comment")
    data = {"body" => comment_text}

    STDERR.puts comment_text

    if !@options["issues"] || @options["issues"].include?(ticket) # can limit to single issue until get the text right.
      resp = RestClient.post(uri, data.to_json, :content_type => :json, :accept=>:json)
      # hash = JSON.parse(resp)
      # do we need to check anything about the response to see if it went ok?
      # it will throw an error if ticket not found or something.
    end
  end

  def check_for_valid_ticket(ticket)
    begin

      uri = build_uri(ticket)
      resp = RestClient.get uri
      hash = JSON.parse(resp)

      if @options["check_status"]
        # Grab the Jira bug status, or fall back to allowing
        # if the format is unexpected.

        status = hash["fields"]["status"]["name"] rescue "open"

        if status.downcase == "closed"
          STDERR.puts "Issue #{ticket} is closed, not allowing."
          return false
        end
      end
      # The bug (probably) isn't closed (or we aren't checking),so we're valid!
      return true
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
    end
    false # if we get to this point it's not a valid ticket
  end

  def commit_list
    # return the list of commits to display. We don't want to show them all
    # (it looks scary when there's a lot)
    # when there's only one, just return the commit
    # when more than one return first_commit..last_commit
    # use the shortened SHA-1 for readability
    return "" if !self.commits || self.commits.empty?

    if self.commits.size == 1
      "#{self.commits.first[0..6]}"
    else
      "#{self.commits.last[0..6]}..#{self.commits.first[0..6]}"
    end
  end


  def add_error_to_report(commit, msg, error_type = "no_jira")
    # remember this error so we can report it later with others by this author
    # store the string we'd like to print out about this commit (commit link and msg)
    # to make it easier to print later
    # (could store commit and message separately and process later if necessary)
    # format:
    # {"email1@test.com"" => {"no_jira" => ["www.github.com/commit/1234 invalid commit message",
    #                                       "www.github.com/commit/6789 also invalid"]
    #                         "invalid_jira" => ["www.github.com/commit/1212 ABC-123 invalid commit message"]}
    # "email2@test.com" => {...} }


    author_email = Hook.shell!("git log #{commit} -1 --pretty='%aN <%aE>'").chomp rescue "no email"
    
    errors_to_report[author_email]  ||= {"no_jira" => [], "invalid_jira" => []}  # in case first error for this author
    errors_to_report[author_email][error_type] << "#{build_commit_uri(commit[0..7])}\n#{msg}"
  end

  def report_errors
    # report any errors we have reported
      require "pony" unless @options["no_send"] || @options["via"] == "no_send" # wait until we need it
                      # NOTE: Pony breaks on Windows so don't use this option in Windows.
      errors_to_report.each do |email, details|
        desc =  build_message(details["no_jira"], details["invalid_jira"])
        STDERR.puts "Warnings for commit from Jira Add Comment Check:\n--"
        STDERR.puts "#{desc}\n--"

        unless @options["no_send"] || @options["via"] == "no_send"
          STDERR.puts "Sending warning email to #{email}"
          ret = Pony.mail :to => email,
                        :from => @options["from"],
                        :subject => @options["subject"],
                        :body => desc,
                        :via => @options["via"],
                        :via_options => @options["via_options"]
        end
      end
  end

  # Build the email message.
  # use the remote repo path for the name of the repo
  # since this is always run as post_receive, there should always be a remote path.

  def build_message(no_jira = [], invalid_jira= [])
    description = @options["intro"] || ""
    description.concat <<DESCRIPTION
This notice is to remind you that you need to include valid Jira ticket
numbers in all of your Git commits!

We encountered the following problems in your recent commits.

DESCRIPTION
    if no_jira.size > 0
      description.concat <<DESCRIPTION
Commits with no reference to any jira tickets:

  #{no_jira.join("\n--\n  ")}
-----
DESCRIPTION
    end

    if invalid_jira.size > 0
      description.concat <<DESCRIPTION
Commits which reference invalid Jira ticket numbers
that don't exist or have already been closed:

  #{invalid_jira.join("\n--\n  ")}
-----
DESCRIPTION
    end

    description.concat @options["conclusion"]  if @options["conclusion"]

    description
  end
end



