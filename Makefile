.PHONY: release bump-version

TODAY := $(shell date +%Y%m%d)
VERSION_FILE := lib/yaml_janitor/version.rb

# Find next available version (handles multiple releases per day)
EXISTING_TAGS := $(shell git tag -l 'v$(TODAY)*')
ifeq ($(EXISTING_TAGS),)
  VERSION := $(TODAY)
else
  # Count existing tags for today and increment
  TAG_COUNT := $(shell git tag -l 'v$(TODAY)*' | wc -l)
  VERSION := $(TODAY).$(TAG_COUNT)
endif

# Bump version to today's date and release
release: bump-version
	bundle install
	git add $(VERSION_FILE) Gemfile.lock
	git commit -m "Bump version to $(VERSION)"
	git tag v$(VERSION)
	git push origin main v$(VERSION)

# Just bump the version without releasing
bump-version:
	@echo "Bumping version to $(VERSION)"
	@sed -i 's/VERSION = "[0-9.]*"/VERSION = "$(VERSION)"/' $(VERSION_FILE)
	@grep VERSION $(VERSION_FILE)
