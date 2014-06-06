# Copyright (C) 2013-2014 OL2, Inc. See LICENSE.txt for details.

# This is a set of Git operations, run via shell.  It permits much
# cleaner unit tests.  Initially it was written in this way because it
# was very small and simple.  Now it should be converted to Grit or a
# similar tool or library.

module RubyGitHooks; end

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
    if !contents.nil?
      File.open(File.join(repo_name, filename), "w") do |f|
        f.write(contents)
      end
    end

    Hook.shell! "cd #{repo_name} && git add #{filename} && git commit -m \"#{commit_message}\""
  end

  def new_single_file_commit(repo_name = "child_repo", contents = "Single-file commit")
    @single_file_counter ||= 1

    filename = "test_file_#{@single_file_counter}"

    new_commit(repo_name, filename, contents)

    @single_file_counter += 1
  end

  def new_multi_file_commit(num_files = 3, repo_name = "child_repo", commit_message = "multi-file commit", base_filename = "test", contents="Contents")
    (1..num_files).each do |num|
      File.open(File.join(repo_name, base_filename + num.to_s), "w") do |f|
        f.write(contents)
      end
    end
    Hook.shell! "cd #{repo_name} && git add . && git commit -m \"#{commit_message}\""

  end

  def git_delete(repo_name="child_repo", filename="file_to_delete")  
    # filename is a file that has already been added and commited to the repo
    Hook.shell! "cd #{repo_name} && git rm #{filename}"
  end
  
  def git_rename(repo_name="child_repo", filename="file_to_rename", new_filename)  
    # filename is a file that has already been added and commited to the repo
    Hook.shell! "cd #{repo_name} && git mv #{filename} #{new_filename}"
  end

  def last_commit_sha(repo_name = "child_repo")
    Hook.shell!("cd #{repo_name} && git log -n 1 --format=%H").chomp
  end

  def git_commit(repo_name = "child_repo", commit_message = "Generic commit message")
    Hook.shell! "cd #{repo_name} && git commit -m \"#{commit_message}\""
  end

  def git_push(repo_name = "child_repo", remote = "origin", branch = "master")
    Hook.shell! "cd #{repo_name} && git push #{remote} #{branch}"
  end

  def rewind_one_commit(repo_name = "child_repo")
    Hook.shell! "cd #{repo_name} && git reset --hard HEAD~"
  end

  def last_commit_message(repo_name = "child_repo")
    Hook.shell!("cd #{repo_name} && git log -1").chomp
  end

  def git_tag(repo_name="child_repo", tagname="0.1")
    Hook.shell! "cd #{repo_name} && git tag -a #{tagname} -m 'test'"
  end

  def git_checkout(repo_name="child_repo", branch_name="master")
    Hook.shell! "cd #{repo_name} && git checkout #{branch_name}"
  end

  def git_create_and_checkout_branch(repo_name="child_repo", branch_name="B1")
    Hook.shell! "cd #{repo_name} && git checkout -b #{branch_name}"
  end

  def git_push_all(repo_name = "child_repo")
    Hook.shell! "cd #{repo_name} && git push --all"
  end

  def git_revlist_all(repo_name = "child_repo")
    Hook.shell!("cd #{repo_name} && git rev-list --all").split("\n")
  end

  def git_merge(repo_name = "child_repo", branch = "B1", msg = "Merge branch #{branch}")
    # better be sure there's not going to be a conflict
    Hook.shell!("cd #{repo_name} && git merge #{branch} --no-ff -m '#{msg}'")
  end

  def git_ff_merge(repo_name = "child_repo", branch = "B1", msg = "Merge branch #{branch}")
    # better be sure there's not going to be a conflict
    Hook.shell!("cd #{repo_name} && git merge #{branch} --ff")
  end

end
