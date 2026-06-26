# Peel — developer quality tasks
#
#   make format        Format all Swift code in place
#   make format-check  Verify formatting (no changes); fails if anything is off
#   make lint          Run SwiftLint
#   make lint-fix       Autofix SwiftLint issues
#   make build         Build the app
#   make test          Build and run the unit tests
#   make quality       Full gate: format-check + lint + test
#   make hooks         Install the git pre-commit hook

SCHEME       = Peel
PROJECT      = Peel.xcodeproj
DESTINATION  = platform=macOS
XCSIFT      := $(shell command -v xcsift 2>/dev/null)

.PHONY: format format-check lint lint-fix build test quality hooks

format:
	swiftformat .

format-check:
	swiftformat . --lint

lint:
	swiftlint lint --quiet

lint-fix:
	swiftlint --fix

build:
ifeq ($(XCSIFT),)
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)'
else
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' | xcsift
endif

test:
ifeq ($(XCSIFT),)
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -only-testing:PeelTests
else
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -only-testing:PeelTests | xcsift
endif

quality: format-check lint test
	@echo "✓ quality checks passed"

hooks:
	git config core.hooksPath .githooks
	@echo "✓ git hooks installed (core.hooksPath = .githooks)"
