# RubyGitHooks

RubyGitHooks sets up a reasonable development environment for git hooks.

Git, by default, gives you information that doesn't instantly map to
what you want.  A pre-receive hook, for instance, doesn't just give
you the content that's being received.  You have to extract it by
running git commands.  If you want to write a pre-receive hook that
can also be used pre-commit, you have to do a fair bit of wrapping.

RubyGitHooks does that extracting and wrapping for you.  It's a
somewhat slower wrapper (but still very fast, this is Git) that can be
far more convenient to write.

## Installation

To use with a single Ruby installation:

    gem install ruby_git_hooks

To use with RVM and all Rubies and gemsets:

    rvm all do bash -l -c "rvm use @global && gem install ruby_git_hooks"

Remember that ruby_git_hooks is invoked by Git -- it won't normally
run with Bundler.  Not only do you not need to add it to your Gemfile,
it probably won't help.  So make sure it's installed for every Ruby
you use day-to-day from the command line.

If you install a new Ruby then you'll need to install ruby_git_hooks
in its global gemset as well.

## Usage

Your new hook should have a Ruby shebang line.  You can require
ruby_git_hooks and/or your hook on the shebang line, or in the text of
the file.  You can use any hooks you want or define your own.

The hook should be copied or symlinked to the appropriate location, of
the form ".git/hooks/hook-name".

Here's an example: a pre-receive hook that uses the shebang line to
require ruby_git_hooks/case_clash, then runs it.

~~~
#!/usr/bin/env ruby -rruby_git_hooks/case_clash
# Put in .git/hooks/pre-receive and make it executable!

RubyGitHooks.run CaseClashHook.new
~~~

### Multiple Git Hooks, One RubyGitHook

You can put a single hook in and symlink it:

~~~
> cp my_hook.rb .git/hooks/pre-receive
> chmod +x .git/hooks/pre-receive
> ln -s .git/hooks/pre-receive .git/hooks/pre-commit
~~~

Obviously this works better when the hook is meaningful in more than
one situation.  You wouldn't want four or five different places to
notify you by email.

### Multiple Hooks and RubyGitHooks.register

You can call register on multiple hooks and then run them:

~~~
#!/usr/bin/env ruby -rruby_git_hooks
# Put in .git/hooks/post-receive and make it executable!
require "case_clash"
require "copyright_check"

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

You can have a single RubyGitHook file and symlink it to *all* your
git hooks, too.  But then you probably don't want every RubyGitHook to
run for each type of git hook -- your pre-commit and post-commit hooks
may be different, for instance.

~~~
#!/usr/bin/env ruby -rruby_git_hooks
# Put in .git/hooks/post-receive and make it executable!
require "case_clash"
require "copyright_check"

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
require "ruby_git_hooks"  # Not in the shebang line, if that's your thing.

class TestHook < RubyGitHooks::Hook
  def check
    fnords = file_contents.values.any? { |v| v.include?("fnord") }

    puts "You may not check in the Fnords!" if fnords

    !fnords
  end
end

RubyGitHooks.run TestHook.new
~~~



## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Future (Unimplemented)

To create a single .git/hooks/ruby_git_hooks executable and symlink
all supported git hooks to it, type "ruby_git_hooks" from your git
root.
