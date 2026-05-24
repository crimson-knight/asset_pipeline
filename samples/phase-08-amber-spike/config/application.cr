# Phase 8 Amber Spike — minimal Amber bootstrap.
#
# Purpose: prove that asset_pipeline can drop into Amber as a view layer
# via `render_screen` helper without wrapping HTTP::Server::Context.

require "amber"

# Phase 8A: lifted helpers now live in the asset_pipeline shard at
# `src/asset_pipeline/amber_integration.cr`. The spike requires the
# production path directly; the old prototype helper at
# `src/lib/asset_pipeline_amber_helpers.cr` is retained for diff
# reference but no longer required.
require "asset_pipeline/amber_integration"

# Load the application code.
require "../src/controllers/application_controller"
require "../src/controllers/sign_in_controller"
require "../src/screens/sign_in_screen"

# Then routes (must come after controllers are defined).
require "./routes"
