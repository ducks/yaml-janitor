# Release Process

yaml-janitor uses date-based versioning (YYYYMMDD) and automated publishing to RubyGems via GitHub Actions.

## Publishing a New Release

1. **Update the version number**

   Edit `lib/yaml_janitor/version.rb`:
   ```ruby
   module YamlJanitor
     VERSION = "20251113"  # Change to today's date
   end
   ```

2. **Update the lockfile**

   ```bash
   bundle install
   ```

3. **Commit and push**

   ```bash
   git add lib/yaml_janitor/version.rb Gemfile.lock
   git commit -m "Bump version to 20251113"
   git push origin main
   ```

4. **Create and push a tag**

   ```bash
   git tag v20251113
   git push origin v20251113
   ```

5. **Verify the release**

   GitHub Actions will automatically:
   - Build the gem
   - Publish to RubyGems using trusted publishing
   - Create a GitHub release

   Check the workflow at: https://github.com/ducks/yaml-janitor/actions

   Verify the gem at: https://rubygems.org/gems/yaml-janitor

## Versioning

We use date-based versioning (YYYYMMDD) instead of semantic versioning.

Rationale: More meaningful, automatic sorting, reflects when changes were made.

## Trusted Publishing Setup

The gem is published using RubyGems Trusted Publishing, which eliminates the need for API keys.

Configuration (already set up):
- RubyGems: https://rubygems.org/settings/trusted_publishing
  - Repository: `ducks/yaml-janitor`
  - Workflow: `publish.yml`
- GitHub Actions: `.github/workflows/publish.yml`

## Requirements

- Ruby >= 3.2.0 (due to Bundler 2.7.2 requirement)
- Tested on Ruby 3.2 and 3.3

## Troubleshooting

### Lockfile out of sync

If the CI fails with lockfile errors, regenerate it:
```bash
rm Gemfile.lock
bundle install
git add Gemfile.lock
git commit -m "Update Gemfile.lock"
```

### Trusted publishing failed

Verify the configuration at https://rubygems.org/settings/trusted_publishing matches:
- Repository owner: `ducks`
- Repository name: `yaml-janitor`
- Workflow filename: `publish.yml` (exact match)
- Environment name: (leave blank)

### Tag already exists

Delete and recreate:
```bash
git tag -d v20251113
git push origin :v20251113
git tag v20251113
git push origin v20251113
```
