# Phase 8 Amber Spike — minimal Amber bootstrap.
#
# Purpose: prove that asset_pipeline can drop into Amber as a view layer
# via `render_screen` helper without wrapping HTTP::Server::Context.

require "amber"

# Load the asset_pipeline Amber-integration helpers (prototype-grade,
# living inside the spike directory until Phase 8A lifts them into
# src/asset_pipeline/amber_integration.cr).
require "../src/lib/asset_pipeline_amber_helpers"

# Load the application code.
require "../src/controllers/application_controller"
require "../src/controllers/sign_in_controller"
require "../src/screens/sign_in_screen"

# Then routes (must come after controllers are defined).
require "./routes"
