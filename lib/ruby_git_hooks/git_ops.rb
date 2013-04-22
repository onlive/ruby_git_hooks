module RubyGitHooks; end

# TODO: this is currently only useful for unit tests, because it's
# very dependent on what directory it's executed from.  Grit can help
# with this while also keeping from messing up the top repo by
# accident.

module RubyGitHooks::GitOps
  extend self

  Hook = RubyGitHooks::Hook

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

  def new_commit(repo_name, filename, contents = "Contents", commit_message = "Single-file commit of #{filename}")
    File.open(File.join(repo_name, filename), "w") do |f|
      f.write(contents)
    end

    Hook.shell! "cd #{repo_name} && git add #{filename} && git commit -m '#{commit_message}'"
  end

  def new_single_file_commit(repo_name = "child_repo", contents = "Single-file commit")
    @single_file_counter ||= 1

    filename = "test_file_#{@single_file_counter}"

    new_commit(repo_name, filename, contents)

    @single_file_counter += 1
  end

  def last_commit_sha(repo_name = "child_repo")
    Hook.shell!("cd #{repo_name} && git log -n 1 --format=%H").chomp
  end

  def git_push(repo_name = "child_repo")
    Hook.shell! "cd #{repo_name} && git push"
  end

  def rewind_one_commit(repo_name = "child_repo")
    Hook.shell! "cd #{repo_name} && git reset --hard HEAD~"
  end
end
