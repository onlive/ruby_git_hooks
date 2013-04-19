# RubyGitHooks

RubyGitHooks sets up a reasonable development environment for git hooks.

Git, by default, gives you information that doesn't instantly map to
what you want.  A pre-receive hook, for instance, doesn't just give
you the content that's being received.  If you want to write a
pre-receive hook that can also be used pre-commit, you have to do a
fair bit of wrapping.

RubyGitHooks does that wrapping for you.

## Installation

To use with a single Ruby installation:

    gem install ruby_git_hooks

To use with RVM and all Rubies and gemsets:

    rvm all do bash -l -c "rvm use @global && gem install ruby_git_hooks"

Remember that ruby_git_hooks is invoked by Git, and so it won't
normally run with Bundler.  Not only do you not need to add it to your
Gemfile, it probably won't help to do so.  So make sure it's installed
for every Ruby you use day-to-day from the command line.

If you install a new Ruby, you'll need to install ruby_git_hooks in
its global gemset as well.

## Usage

Your new hook should have a Ruby shebang line, require
"ruby_git_hooks", and then any hooks you want to use.

The hook should be copied or symlinked to the appropriate location, of
the form ".git/hooks/hook-name".

~~~
#!/usr/bin/env ruby
# .git/hooks/pre-receive

require "ruby_git_hooks/all"

RubyGitHooks.run CaseClashHook
~~~

You can also require "ruby_git_hooks" and then the specific hooks you
want, then call Hook.run with no arguments.  It will run a standard
set of hooks that don't require configuration.

Some hooks won't run until configured.  For instance, the Jira-check
hook needs to know where your Jira server is before it can do anything
useful.

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
