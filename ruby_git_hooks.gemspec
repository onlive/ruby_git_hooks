# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ruby_git_hooks/version'

Gem::Specification.new do |spec|
  spec.name          = "ruby_git_hooks"
  spec.version       = RubyGitHooks::VERSION
  spec.authors       = ["Noah Gibbs", "Ruth Helfinstein", "Alex Snyatkov"]
  spec.email         = ["noah@onlive.com", "ruth.helfinstein@onlive.com",
                        "alex.snyatkov@onlive.com"]
  spec.description   = <<DESC
Ruby_git_hooks is a library to allow easy writing and installing of
git hooks in Ruby.  It abstracts away the differences between
different hook interfaces and supplies implementations of some common
Git hooks.  It allows overriding "git clone" to automatically
install your prefered hooks.
DESC
  spec.summary       = %q{DSL and manager for git hooks in Ruby.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
  spec.bindir        = "bin"

  spec.add_runtime_dependency "pony"  # For email
  spec.add_runtime_dependency "rest-client"
  spec.add_runtime_dependency "json"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "rr"
  spec.add_development_dependency "rake"
end
