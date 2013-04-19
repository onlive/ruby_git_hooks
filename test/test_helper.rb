# TODO: coverage?

# Test local copy first
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), "..", "lib")

require "minitest/pride"
require "ruby_git_hooks"
