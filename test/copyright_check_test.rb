require "test_helper"

require "minitest/autorun"
require "pony"

class CopyrightCheckHookTest < HookTestCase
  REPOS_DIR = File.expand_path File.join(File.dirname(__FILE__), "repos")
  FAKE_MAILER = File.join(File.dirname(__FILE__), "fake_mailer")
  MAILER_FILE = File.join(File.dirname(__FILE__), "mail_params")
  TEST_HOOK_BASIC = <<TEST
#!/usr/bin/env ruby
require "ruby_git_hooks/copyright_check"

RubyGitHooks.register CopyrightCheckHook.new("domain" => "onlive.com",
  "from" => "Copyright Enforcement <noreply@onlive.com>",
  "via" => :sendmail,
  "via_options" => {
    :location => #{FAKE_MAILER.inspect},
    :arguments => '#{MAILER_FILE.inspect}'
  }
)

RubyGitHooks.run
TEST

  TEST_HOOK_NO_SEND = <<TEST
#!/usr/bin/env ruby
require "ruby_git_hooks/copyright_check"

RubyGitHooks.run CopyrightCheckHook.new("no_send" => true)
TEST

  def setup
    # Empty out the test repos dir
    Hook.shell! "rm -rf #{File.join(REPOS_DIR, "*")}"

    # Remove test mail file
    Hook.shell! "rm -f #{MAILER_FILE}"

    # Create local parent and child repos with a single shared commit
    Dir.chdir REPOS_DIR

    new_bare_repo
    clone_repo
    new_commit "child_repo", "README"
    git_push
  end

  def test_copyright_post_commit
    add_hook("child_repo", "post-commit", TEST_HOOK_BASIC)

    new_commit("child_repo", "myfile.rb", <<FILE_CONTENTS)
# No copyright notice!
FILE_CONTENTS

    mail_out = File.read MAILER_FILE

    # Should get email with the most recent commit about
    # myfile.rb, which has no copyright notice.
    assert mail_out.include?(last_commit_sha),
      "Mail message must include latest SHA!"
    assert mail_out.include?("myfile.rb"),
      "Mail message must mention myfile.rb!"
  end

  def test_copyright_no_send_option
    add_hook("child_repo", "post-commit", TEST_HOOK_NO_SEND)

    new_commit("child_repo", "myfile.rb", <<FILE_CONTENTS)
# No copyright notice!
FILE_CONTENTS

    assert !File.exist?(MAILER_FILE),
      "Copyright test must not send email if 'no_send' is set!"
  end

  def test_copyright_basic_correct
    add_hook("child_repo", "post-commit", TEST_HOOK_BASIC)

    new_commit("child_repo", "myfile.rb", <<FILE_CONTENTS)
# Copyright (C) 1941-2013 YoyoDyne, Inc.  All Rights Reserved.
FILE_CONTENTS

    assert !File.exist?(MAILER_FILE), "Copyright test must not send email!"
  end

  def test_copyright_no_first_year
    add_hook("child_repo", "post-commit", TEST_HOOK_BASIC)

    new_commit("child_repo", "myfile.rb", <<FILE_CONTENTS)
# Copyright (C) 2013 YoyoDyne, Inc.  All Rights Reserved.
FILE_CONTENTS

    assert !File.exist?(MAILER_FILE), "Copyright test must not send email!"
  end

end
