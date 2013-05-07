require "ruby_git_hooks"

class CopyrightCheckHook < RubyGitHooks::Hook
  COPYRIGHT_REGEXP = /Copyright\s+\(C\)\s*(?<pre_year>.*)-?(?<cur_year>\d{4})\s+(?<company>.+)\s+all rights reserved\.?/i

  # Only check files with known checkable extensions
  EXTENSIONS = [
                "c", "cpp", "cc", "cp",
                "h", "hp", "hpp",
                "m", "mm",
                "java",
                "bat",
                "sh",
                "ps1",
                "rb",
               ]

  OPTIONS = [ "domain", "from", "subject", "via", "via_options", "intro",
              "no_send", "company_check" ]

  Hook = RubyGitHooks::Hook

  def initialize(options = {})
    bad_options = options.keys - OPTIONS
    raise "CopyrightCheckHook created with unrecognized options: " +
      "#{bad_options.inspect}!" if bad_options.size > 0

    @options = options
    @options["domain"] ||= "mydomain.com"
    @options["from"] ||= "Copyright Cop <noreply@#{@options["domain"]}>"
    @options["subject"] ||= "Copyright Your Files, Please!"
    @options["via"] ||= "no_send"
    @options["via_options"] ||= {}
  end

  # TODO: use Regexp#scan instead of just the first match
  def check
    no_notice = []
    outdated_notice = []
    outdated_company = []

    cur_year = Time.now.strftime("%Y")

    files_changed.each do |filename|
      extension = (filename.split(".") || [])[-1]
      next unless EXTENSIONS.include?(extension)
      next if file_contents[filename] == ""  # for now this is how we recognize a deleted file.
      if file_contents[filename] =~ COPYRIGHT_REGEXP
        parsed_cur_year = $~["cur_year"]
        parsed_company = $~["company"]

        unless parsed_cur_year == cur_year
          outdated_notice << filename
        end

        # If there is a "company_check" option, either a string
        # or regexp, make sure that the detected company name
        # matches it.
        if @options["company_check"] &&
            !(parsed_company[@options["company_check"]])
          outdated_company << filename
        end
      else
        no_notice << filename
      end
    end

    bad_num = no_notice.size + outdated_notice.size + outdated_company.size
    return true if bad_num < 1

    desc = build_description(no_notice, outdated_notice, outdated_company)

    recipients = {}
    self.commits.each do |commit|
      author = Hook.shell!("git log -n 1 --pretty=format:\"%aE %aN\" #{commit}")
      email, name = author.chomp.split(" ", 2)
      recipients[name] = email
    end

    unless @options["no_send"] || @options["via"] == "no_send"
        require "pony"  # wait until we need it
                        # NOTE: Pony breaks on Windows so don't use this option in Windows.
        recipients.each do |name, email|
        ret = Pony.mail :to => email,
                  :from => @options["from"],
                  :subject => @options["subject"],
                  :body => desc,
                  :via => @options["via"],
                  :via_options => @options["via_options"]
      end
    end

    puts "Warnings for commit:\n#{desc}"

    # Block commit if installed as a pre-commit or pre-receive hook
    false
  end

  protected

  #
  # Return an appropriate email based on the set of files with
  # problems.  If you need a different format, please inherit from
  # CopyrightCheckHook and override this method.
  #
  def build_description(no_notice, outdated_notice, outdated_company)
    bad_files = no_notice | outdated_notice | outdated_company

    description = @options["intro"] || ""
    description.concat <<DESCRIPTION
In your commit(s): #{self.commits.join(" ")}

You have outdated, inaccurate or missing copyright notices.

Specifically:
=============
DESCRIPTION

    if outdated_notice.size > 0
      description.concat <<DESCRIPTION
The following files do not list #{cur_year} as the copyright year:

  #{outdated_notice.join("\n  ")}
-----
DESCRIPTION
    end

    if outdated_company.size > 0
      description.concat <<DESCRIPTION
The following files do not properly list your company as the holder of copyright:

  #{outdated_company.join("\n  ")}

DESCRIPTION
    end

    if no_notice.size > 0
      description.concat <<DESCRIPTION
The following files have no notice or a notice I didn't recognize:

  #{no_notice.join("\n  ")}

DESCRIPTION

    description.concat <<DESCRIPTION
All files with problems:

  #{bad_files.join("\n  ")}
DESCRIPTION
    end

    description
  end
end
