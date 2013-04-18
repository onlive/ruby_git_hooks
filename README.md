# RubyGitHooks

RubyGitHooks sets up a reasonable development environment for git hooks.

Git, by default, gives you information that doesn't instantly map to
what you want.  A pre-receive hook, for instance, doesn't just give
you the content that's being received.  If you want to write a
pre-receive hook that can also be used pre-commit, you have to do a
fair bit of wrapping.

RubyGitHooks does that wrapping for you.

## Installation

Add this line to your application's Gemfile:

    gem 'ruby_git_hooks'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ruby_git_hooks

## Usage

Your new hook should have a Ruby shebang line, require
"ruby_git_hooks", and then any hooks you want to use.

The hook should be copied or symlinked to the appropriate location, of
the form ".git/hooks/hook-name".

~~~
#!/usr/bin/env ruby
# .git/hooks/pre-receive

require "ruby_git_hooks/all"

Hook.run :case_check
~~~

You can also require "ruby_git_hooks" and then the specific hooks you
want, then call Hook.run with no arguments.  It will run all
registered hooks, which is probably not what you want with "all"
required.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
