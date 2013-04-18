require "ruby_git_hooks"

module RubyGitHooks
  class CaseClashHook < Hook
    def self.check
      out = `git ls-files`
      downcase_hash = {}

      out.split("\n").map(&:strip).each do |filename|
        downcase_hash[filename.downcase] ||= []
        downcase_hash[filename.downcase].push filename
      end

      not_okay = false
      downcase_hash.each do |_, filenames|
        if filenames.length > 1
          not_okay = true
          STDERR.puts "Duplicate-except-case files detected: #{filenames.inspect}"
        end
      end

      not_okay
    end

    Hook.register(:case_clash, self)
  end
end
