# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "lib"
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: :test

desc "Bump version to today's date, update lockfile, commit, and merge to main"
task :release do
  require_relative "lib/yaml_janitor/version"

  # Generate today's version
  new_version = Time.now.strftime("%Y%m%d")
  current_version = YamlJanitor::VERSION

  if new_version == current_version
    puts "Version is already #{new_version}"
    puts "If you want to re-release, manually edit lib/yaml_janitor/version.rb"
    exit 1
  end

  puts "Bumping version from #{current_version} to #{new_version}..."

  # Make sure we're on main
  current_branch = `git rev-parse --abbrev-ref HEAD`.strip
  if current_branch != "main"
    puts "Error: Must be on main branch to release (currently on '#{current_branch}')"
    abort("Checkout main and try again")
  end

  # Create feature branch
  branch_name = "release/v#{new_version}"
  puts "Creating branch #{branch_name}..."
  system("git checkout -b #{branch_name}") || abort("Failed to create branch")

  # Update version.rb
  version_file = "lib/yaml_janitor/version.rb"
  content = File.read(version_file)
  content.gsub!(/VERSION = "#{current_version}"/, "VERSION = \"#{new_version}\"")
  File.write(version_file, content)

  # Update lockfile
  puts "Updating Gemfile.lock..."
  system("bundle install") || abort("Failed to update Gemfile.lock")

  # Commit changes
  puts "Committing changes..."
  system("git add lib/yaml_janitor/version.rb Gemfile.lock") || abort("Failed to git add")
  system("git commit -m 'Bump version to #{new_version}'") || abort("Failed to commit")

  # Switch back to main
  puts "Switching back to main..."
  system("git checkout main") || abort("Failed to checkout main")

  # Merge with --no-ff
  puts "Merging #{branch_name} to main..."
  system("git merge --no-ff #{branch_name}") || abort("Failed to merge")

  # Delete feature branch
  puts "Deleting branch #{branch_name}..."
  system("git branch -d #{branch_name}")

  # Create tag
  tag = "v#{new_version}"
  puts "Creating tag #{tag}..."
  system("git tag #{tag}") || abort("Failed to create tag")

  puts ""
  puts "✓ Release #{new_version} prepared!"
  puts ""
  puts "Next steps (manual):"
  puts "  1. git push origin main"
  puts "  2. git push origin #{tag}"
  puts ""
  puts "After pushing, GitHub Actions will:"
  puts "  - Run tests on Ruby 3.2 and 3.3"
  puts "  - Build the gem"
  puts "  - Publish to RubyGems"
  puts ""
  puts "Monitor the release:"
  puts "  - Actions: https://github.com/ducks/yaml-janitor/actions"
  puts "  - RubyGems: https://rubygems.org/gems/yaml-janitor"
end
