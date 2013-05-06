require "test_helper"

require "minitest/autorun"

class MaxFileSizeHookTest < HookTestCase
  REPOS_DIR = File.expand_path File.join(File.dirname(__FILE__), "repos")
  TEST_HOOK_BODY = <<TEST
#{RubyGitHooks.shebang}
require "ruby_git_hooks/max_file_size"

RubyGitHooks.run MaxFileSizeHook.new(100000)
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

  def test_max_file_size_pre_receive
    add_hook("parent_repo.git", "pre-receive", TEST_HOOK_BODY)
    filename = "#{REPOS_DIR}/child_repo/BigFile.log"   
    puts "**** about to write #{filename} ******"
       
   File.open("filename", "w") do |f|
      alphanum =  [('a'..'z'),('A'..'Z'),('0'..'9')].map{|i| i.to_a}.flatten
      string  =  (0...120000).map{ alphanum[rand(alphanum.length)] }.join
      f.write(string)
      puts "**** wrote big file ******"
    end
    new_commit "child_repo", "BigFile.log", nil

    # Should reject w/ pre-commit hook
    # TODO: check error more specifically
    assert_raises RuntimeError do
      git_push
    end
  end
  

  #def test_case_clash_pre_commit
  #  add_hook("parent_repo.git", "pre-receive", TEST_HOOK_BODY)
  #end

end
