# Copyright (C) 2013-2014 OL2, Inc. See LICENSE.txt for details.

require "test_helper"

require "minitest/autorun"
require "pony"

class RealCopyrightCheckHookTest < HookTestCase
  REPOS_DIR = File.expand_path File.join(File.dirname(__FILE__), "repos")
  FAKE_MAILER = File.join(File.dirname(__FILE__), "fake_mailer")
  MAILER_FILE = File.join(File.dirname(__FILE__), "mail_params")
  CURRENT_YEAR = Time.now.strftime("%Y")
  TEST_HOOK_BASIC = <<TEST
#{RubyGitHooks.shebang}
require "ruby_git_hooks/copyright_check"

RubyGitHooks.register CopyrightCheckHook.new("domain" => "example.com",
  "from" => "Copyright Enforcement <noreply@example.com>",
  "via" => :sendmail,
  "via_options" => {
    :location => #{FAKE_MAILER.inspect},
    :arguments => '#{MAILER_FILE.inspect}'
  }
)

RubyGitHooks.run
TEST

  TEST_HOOK_COMPANY = <<TEST
#{RubyGitHooks.shebang}
require "ruby_git_hooks/copyright_check"

RubyGitHooks.register CopyrightCheckHook.new("domain" => "example.com",
  "from" => "Copyright Enforcement <noreply@example.com>",
  "company_check" => /YoYoDyne (Industries)?/i,
  "via" => :sendmail,
  "via_options" => {
    :location => #{FAKE_MAILER.inspect},
    :arguments => '#{MAILER_FILE.inspect}'
  }
)

RubyGitHooks.run
TEST

  TEST_HOOK_NO_SEND = <<TEST
#{RubyGitHooks.shebang}
require "ruby_git_hooks/copyright_check"

RubyGitHooks.run CopyrightCheckHook.new("no_send" => true)
TEST

  TEST_HOOK_EXCLUDE = <<TEST
#{RubyGitHooks.shebang}
require "ruby_git_hooks/copyright_check"

RubyGitHooks.register CopyrightCheckHook.new("domain" => "example.com",
  "from" => "Copyright Enforcement <noreply@example.com>",
  "via" => :sendmail,
  "via_options" => {
    :location => #{FAKE_MAILER.inspect},
    :arguments => '#{MAILER_FILE.inspect}'
  },
  "exclude_files" => ["schema.rb"]
)

RubyGitHooks.run
TEST

  def setup
    # Empty out the test repos dir
    Hook.shell! "rm -rf #{File.join(REPOS_DIR, "*")}"

    # Remove test mail file
    Hook.shell! "rm -f #{MAILER_FILE}"
    raise "Couldn't delete #{MAILER_FILE}!" if File.exist? MAILER_FILE

    # Create local parent and child repos with a single shared commit
    Dir.chdir REPOS_DIR

    new_bare_repo
    clone_repo
    new_commit "child_repo", "README"
    git_push
  end

  def test_copyright_post_commit
    add_hook("child_repo", "post-commit", TEST_HOOK_BASIC)

    new_commit("child_repo", "file_w_no_copy_notice.rb", <<FILE_CONTENTS)
# No copyright notice!
FILE_CONTENTS

    mail_out = File.read MAILER_FILE

    # Should get email with the most recent commit about
    # file_w_no_copy_notice.rb, which has no copyright notice.
    assert mail_out.include?(last_commit_sha[0..6]),
      "Mail message must include latest SHA!"
    assert mail_out.include?("file_w_no_copy_notice.rb"),
      "Mail message must mention file_w_no_copy_notice.rb!"
  end

  def test_copyright_no_send_option
    add_hook("child_repo", "post-commit", TEST_HOOK_NO_SEND)

    new_commit("child_repo", "file_w_no_copy_notice_but_nosend.rb", <<FILE_CONTENTS)
# No copyright notice!
FILE_CONTENTS

    assert !File.exist?(MAILER_FILE),
      "Copyright test must not send email if 'no_send' is set!"
  end

  def test_copyright_basic_correct
    add_hook("child_repo", "post-commit", TEST_HOOK_BASIC)

    new_commit("child_repo", "correct_file.rb", <<FILE_CONTENTS)
# Copyright (C) 1941-#{CURRENT_YEAR} YoyoDyne, Inc.  All Rights Reserved.
FILE_CONTENTS

    assert !File.exist?(MAILER_FILE), "Copyright test must not send email!"
  end

  def test_copyright_company_correct
    add_hook("child_repo", "post-commit", TEST_HOOK_COMPANY)

    new_commit("child_repo", "correct_file.rb", <<FILE_CONTENTS)
# Copyright (C) 1941-#{CURRENT_YEAR} YoyoDyne Industries  All Rights Reserved.
FILE_CONTENTS

    assert !File.exist?(MAILER_FILE), "Copyright test must not send email!"
  end

  def test_copyright_company_incorrect
    add_hook("child_repo", "post-commit", TEST_HOOK_COMPANY)

    new_commit("child_repo", "correct_file.rb", <<FILE_CONTENTS)
# Copyright (C) 1941-#{CURRENT_YEAR} YoyoWrong  All Rights Reserved.
FILE_CONTENTS

    assert File.exist?(MAILER_FILE), "Must email about wrong company name!"
  end

  def test_copyright_no_first_year
    add_hook("child_repo", "post-commit", TEST_HOOK_BASIC)

    new_commit("child_repo", "correct_file_single_year.rb", <<FILE_CONTENTS)
# Copyright (C) #{CURRENT_YEAR} YoyoDyne, Inc.  All Rights Reserved.
FILE_CONTENTS

    assert !File.exist?(MAILER_FILE), "Copyright test must not send email!"
  end

  def test_copyright_wrong_year
    add_hook("child_repo", "post-commit", TEST_HOOK_COMPANY)

    new_commit("child_repo", "correct_file.rb", <<FILE_CONTENTS)
# Copyright (C) 2012 YoyoDyne, Inc.  All Rights Reserved.
FILE_CONTENTS

    assert File.exist?(MAILER_FILE), "Must email about wrong date!"
  end

  def test_copyright_exclude_files
    add_hook("child_repo", "post-commit", TEST_HOOK_EXCLUDE)
    new_commit("child_repo", "schema.rb", <<FILE_CONTENTS)
# NO copyright but I'm an excluded file.
FILE_CONTENTS
    assert !File.exist?(MAILER_FILE), "Copyright test must not send email!"
  end

end
