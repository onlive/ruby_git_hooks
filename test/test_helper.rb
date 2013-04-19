# TODO: coverage?

# Test local copy first
$LOAD_PATH.unshift File.join(File.dirname(__FILE__), "..", "lib")

require "minitest/pride"
require "ruby_git_hooks"

class HookTestCase < MiniTest::Unit::TestCase
  include RubyGitHooks

  def new_bare_repo(name = "parent_repo.git")
    Hook.shell! "mkdir #{name} && cd #{name} && git init --bare"
  end

  def clone_repo(parent_name = "parent_repo.git", child_name = "child_repo")
    Hook.shell! "git clone #{parent_name} #{child_name}"
  end

  def add_hook(repo_name, hook_name, contents)
    # We're adding to either a normal or bare directory.
    # Check for hooks directory.
    if File.exist? "#{repo_name}/.git/hooks"
      hooks_dir = "#{repo_name}/.git/hooks"
    elsif File.exist? "#{repo_name}/hooks"
      hooks_dir = "#{repo_name}/hooks"
    else
      raise "Can't locate hooks directory under #{repo_name.inspect}!"
    end

    filename = File.join(hooks_dir, hook_name)
    File.open(filename, "w") do |f|
      f.write(contents)
    end
    Hook.shell!("chmod +x #{filename}")
  end

  def new_single_file_commit(repo_name = "child_repo", contents = "Single-file commit")
    @single_file_counter ||= 1

    filename = "test_file_#{@single_file_counter}"

    File.open(File.join(repo_name, filename), "w") do |f|
      f.write(contents)
    end

    Hook.shell! "cd #{repo_name} && git add #{filename} && git commit -m 'Single-file commit of #{filename}'"

    @single_file_counter += 1
  end

  def git_push(repo_name = "child_repo")
    Hook.shell! "cd #{repo_name} && git push"
  end
end
