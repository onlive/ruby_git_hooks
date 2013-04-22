require "test_helper"

require "minitest/autorun"
require "pony"

class CopyrightCheckHookTest < HookTestCase
  REPOS_DIR = File.expand_path File.join(File.dirname(__FILE__), "repos")
  FAKE_MAILER = File.join(File.dirname(__FILE__), "fake_mailer")
  MAILER_FILE = File.join(File.dirname(__FILE__), "mail_params")
  TEST_HOOK_BODY_1 = <<TEST
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

  def setup
    # Empty out the test repos dir
    Hook.shell! "rm -rf #{File.join(REPOS_DIR, "*")}"

    # Create local parent and child repos with a single shared commit
    Dir.chdir REPOS_DIR

    new_bare_repo
    clone_repo
    new_commit "child_repo", "README"
    git_push
  end

  def test_copyright_post_commit
    add_hook("child_repo", "post-commit", TEST_HOOK_BODY_1)

    new_commit("child_repo", "myfile.rb", <<FILE_CONTENTS)
# No copyright notice!
FILE_CONTENTS

    mail_out = File.read MAILER_FILE

    # Should get email with the most recent commit about
    # myfile.rb, which has no copyright notice.
    assert mail_out.include?(last_commit_sha)
    assert mail_out.include?("myfile.rb")
  end

end
