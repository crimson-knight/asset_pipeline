require "../src/ui/design_tokens"
require "../src/ui/design_tokens/generators/web_generator"
require "../src/ui/design_tokens/generators/apple_generator"

# Regenerate every committed design-tokens dist artifact from the current
# `UI::DesignTokens::Tokens.default`. Run with `crystal run scripts/regenerate_design_tokens.cr`.
#
# Output is deterministic: invoking the script twice in a row produces
# identical bytes. The CI / pre-commit guard can re-run this script and
# `git diff --exit-code` to detect drift between the Crystal source of truth
# and the committed dist files.
#
# Android XML generator is deferred per
# `docs/initiative-cross-platform-ui/handoff/phase-01-architect-scope-deferral-2026-05-20.md`.

repo_root = File.expand_path("..", __DIR__)
tokens = UI::DesignTokens::Tokens.default

web_path = File.join(repo_root, "src/ui/design_tokens/dist/web_tokens.css")
File.write(web_path, UI::DesignTokens::WebGenerator.generate(tokens))
puts "wrote #{web_path}"

apple_path = File.join(repo_root, "src/ui/design_tokens/dist/AssetPipelineTokens.swift")
File.write(apple_path, UI::DesignTokens::AppleGenerator.generate(tokens))
puts "wrote #{apple_path}"
