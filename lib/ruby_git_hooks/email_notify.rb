require "ruby_git_hooks"
require "pony"

class EmailNotifyHook < RubyGitHooks::Hook
  LEGAL_OPTIONS = [ "no_send", "via", "via_options", "max_lines", "recipients" ]

  def initialize(options = {})
    bad_opts = options.keys - LEGAL_OPTIONS
    unless bad_opts.empty?
      STDERR.puts "Called EmailNotifyHook with bad options: #{bad_opts.inspect}!"
      exit 1
    end

    @options = options
    @options["max_lines"] ||= 300

    unless @options["recipients"]
      raise "Must specify at least one recipient to EmailNotifyHook!"
    end
  end

  def check
    content = file_diffs.flat_map { |path, diff| ["", path, diff] }.join("\n")
    if content.split("\n").size > options["max_lines"]
      content = "Diffs are too big.  Skipping them.\nFiles:\n" +
        file_diffs.keys.join("\n")
    end

    recipients = @options.recipients.split /,|;/

    unless @options["no_send"] || @options["via"] == "no_send"
      recipients.each do |name, email|
        ret = Pony.mail :to => email,
                  :from => @options["from"],
                  :subject => @options["subject"],
                  :body => desc,
                  :via => @options["via"],
                  :via_options => @options["via_options"]
      end
    end

    true
  end
end
