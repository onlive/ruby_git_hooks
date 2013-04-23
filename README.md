# RubyGitHooks

RubyGitHooks sets up a reasonable development environment for git hooks.

Git, by default, gives you information that doesn't instantly map to
what you want.  A pre-receive hook, for instance, doesn't just give
you the content that's being received.  You have to extract the
content by running git commands.  If you want to write a pre-receive
hook that can also be used pre-commit, you have to do a fair bit of
wrapping.

RubyGitHooks does that extracting and wrapping for your convenience.

## Installation

To use with a single Ruby installation:

    gem install ruby_git_hooks

Remember that ruby_git_hooks is invoked by Git -- it won't normally
run with Bundler.  Not only do you not need to add it to your Gemfile,
it probably won't help.  So make sure ruby_git_hooks is installed for
every Ruby you use day-to-day from the command line.

## Usage

Your new hook script should have a Ruby shebang line (see below).  You
can use the included hooks or define your own.

The hook should be copied or symlinked to the appropriate location, of
the form ".git/hooks/hook-name".

Here's an example: a pre-receive hook that uses the shebang line to
require ruby_git_hooks/case_clash, then runs it.

~~~
#!/usr/bin/env ruby
# Put this file in .git/hooks/pre-receive and make it executable!
require "ruby_git_hooks/case_clash"

RubyGitHooks.run CaseClashHook.new
~~~

### Multiple Git Hooks, One RubyGitHook

You can put a single hook script in and symlink it from one or more
git-hook locations:

~~~
> cp my_hook.rb .git/hooks/
> chmod +x .git/hooks/my_hook.rb
> ln -s .git/hooks/my_hook.rb .git/hooks/pre-commit
> ln -s .git/hooks/my_hook.rb .git/hooks/pre-receive
~~~

Use this when the hook is meaningful in more than one situation.
Watch out!  You don't want four or five of the same email
notification.

### Multiple Hooks and RubyGitHooks.register

You can call register on multiple hooks and then run them:

~~~
#!/usr/bin/env ruby
# Put in .git/hooks/post-receive and make it executable!
require "ruby_git_hooks/case_clash"
require "ruby_git_hooks/copyright_check"

RubyGitHooks.register CaseClashHook.new
RubyGitHooks.register CopyrightCheck.new "domain" => "onlive.com",
       "from" => "OnLive Copyright Reminders",
       "via" => {
                  :address => "smtp.onlive.com",
                  :domain => "onlive.com"
                }

RubyGitHooks.run  # Run both
~~~

### Run By Git Hook Type

You can have a single RubyGitHook file and symlink it to all supported
git hooks.  But then you probably don't want every RubyGitHook to run
for each type of git hook -- your pre-commit and post-commit hooks may
be different, for instance.

~~~
#!/usr/bin/env ruby
# Put in .git/hooks/post-receive and make it executable!
require "ruby_git_hooks/case_clash"
require "ruby_git_hooks/copyright_check"

if RubyGitHooks.run_as_hook =~ /pre-/
  RubyGitHooks.run CaseClashHook.new
end

if RubyGitHooks.run_as_hook =~ /post-/
  RubyGitHooks.run CopyrightCheck.new "domain" => "onlive.com",
       "from" => "OnLive Copyright Reminders",
       "via" => {
                  :address => "smtp.onlive.com",
                  :domain => "onlive.com"
                }
end
~~~

### New Hook Types

You can declare a new hook type in your file if you like:

~~~
#!/usr/bin/env ruby
require "ruby_git_hooks"

class TestHook < RubyGitHooks::Hook
  def check
    fnords = file_contents.values.any? { |v| v.include?("fnord") }

    puts "You may not check in the Fnords!" if fnords

    !fnords
  end
end

RubyGitHooks.run TestHook.new
~~~

### Using RubyGitHooks with RVM

To use with RVM and all Rubies and gemsets:

    rvm all do bash -l -c "rvm use @global && gem install ruby_git_hooks"

If you install a new Ruby then you'll need to install ruby_git_hooks
in its global gemset as well.

If you're using Git 1.7.X rather than 1.8.X, Git will prepend /usr/bin
to your path before running your hook -- you'll probably get the
system Ruby by accident instead of the one you want.  You can upgrade
to Git 1.8.X, or create an rvm wrapper and use that.

To create an rvm wrapper:

    rvm wrapper 1.9.3 githooks ruby

You can give your own Ruby version instead of 1.9.3, and an optional
gemset if you want the git hooks to use one.  Then see "Using
RubyGitHooks with a Custom Shebang Line" below.

### Using RubyGitHooks with a Custom Shebang Line

If you don't want to use your current Ruby (with Git 1.8.X) or system
Ruby (with Git 1.7.X), you'll need to set the shebang line for your
hooks to the appropriate interpreter.

If you're creating your own hook files, it's clear how to do this.

But for RubyGitHooks' unit tests and generated hooks, you'll need to
tell it what shebang line to use.

Set it as an environment variable:

    > export RUBYGITHOOKS_SHEBANG='#!/usr/bin/env /home/UserName/.rvm/bin/githooks_ruby'

You need this set when generating hook scripts or running the unit
tests of RubyGitHooks itself, but not later when using the hooks.

You need the /usr/bin/env in it because your wrapper is a shellscript,
and a shebang can't point to another shellscript on most systems.

## Troubleshooting

### It Says It's Not Installed

Sometimes you can get an error saying that ruby_git_hooks isn't
installed when you try a git operation.  Please see
bin/onlive_git_hooks for a big chunk of useful diagnostic info you may
want when debugging this problem.

Simple stuff to try:

* Reinstall ruby_git_hooks in all RVM Rubies (see INSTALLATION) and
  the system Ruby, if any.

* Upgrade Git to 1.8.2 or higher.

* If you don't use /usr/bin/ruby, move it to /usr/bin/old_ruby so it
  doesn't get in the way.  Your system Ruby is probably ancient Ruby
  1.8.7 and everything sane uses 1.9.2 or higher.

Obvious problems:

* Not installed.  Fix this for the Ruby or gemset that git runs.

* Running in a wrong/unexpected Ruby.  Often this is /usr/bin/ruby,
  the system Ruby and/or Ruby 1.8.7.  You can move the bad Ruby out of
  the way.  Or you can install ruby_git_hooks into it.  Or you can
  adjust paths, shebang lines and environment variables to make git
  run the right Ruby.  Note that Git 1.7 adds /usr/bin to the front of
  your path so you may get an expected Ruby.  Git 1.8 does not.
  Consider upgrading.

* Running in Bundler without meaning to.  If your hook's shebang
  includes or can run Bundler and you're using a Gemfile without
  ruby_git_hooks then it's basically not installed.  Usually the right
  answer is "don't run Bundler for your git hooks."  Otherwise you'll
  have to add ruby_git_hooks to your Gemfile and/or add a new Gemfile
  to .git/hooks.

### Ruby 1.8.7

We specifically do not test on Ruby 1.8.7.

We don't try to sabotage it, but it's not on our radar.

There's a good chance that ruby_git_hooks doesn't work on 1.8.7 at any
given time.  This won't change.  Ruby 1.8.7 is ancient and as of June
2013 will no longer even receive security fixes.  Please upgrade.
Seriously, it's time.

We *do* support systems like Macs with 1.8.7 as /usr/bin/ruby.  But
you may need a custom shebang line with an rvm wrapper.

### Git 1.7

Git 1.7 has had some problems, and may have more.  Specifically:

* Git 1.7 does not set up parent-branch tracking by default, and
  some of our unit tests may require that.
* Git 1.7 prepends /usr/bin to the path when running hooks (see above).

We make a best effort to support it, but 1.8 is a smoother experience.

## Contributing to RubyGitHooks

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Future (Unimplemented)

To create a single .git/hooks/ruby_git_hooks executable and symlink
all supported git hooks to it, type "ruby_git_hooks" from your git
root.  Right now there is only an OnLive-specific example of this.
