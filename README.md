# Asset Pipeline

Asset Pipeline is a shard written to handle 3 types of assets:
- Javascript, by using ESM modules and import maps  (Done! v0.34)
- CSS/SASS, by utilizing Node SASS from an import map (TBD)
- Images (TBD)

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     asset_pipeline:
       github: amberframework/asset_pipeline
       version: 0.36.0
   ```

2. Run `shards install`

## Usage

View the full documentation for the [current version here](https://amberframework.github.io/asset_pipeline/AssetPipeline/FrontLoader.html)

For the fullest examples, please view the docs for `AssetPipeline::FrontLoader`.

The `FrontLoader` class is the primary class to use for handling all of your assets with the AssetPipeline, including the `ImportMaps`.

## Features

### Automatic Cache Clearing

As of version 0.36.0, the Asset Pipeline includes automatic cache clearing to help manage cached files during development and deployment.

**Problem:** Previously, cached JavaScript files would accumulate in the output directory without being automatically cleaned up, requiring manual intervention.

**Solution:** Automatic cache clearing is now **enabled by default**! Just initialize your `FrontLoader` normally:

```crystal
# Automatic cache clearing is enabled by default
front_loader = AssetPipeline::FrontLoader.new(
  js_source_path: Path["src/javascript"], 
  js_output_path: Path["public/javascript"]
) do |import_maps|
  import_map = AssetPipeline::ImportMap.new("application", Path["/javascript"])
  import_map.add_import("@hotwired/stimulus", "https://unpkg.com/@hotwired/stimulus/dist/stimulus.js")
  import_maps << import_map
end
```

**To disable cache clearing (for troubleshooting):**
```crystal
# Explicitly disable cache clearing if needed
front_loader = AssetPipeline::FrontLoader.new(
  js_source_path: Path["src/javascript"], 
  js_output_path: Path["public/javascript"],
  clear_cache_upon_change: false  # Disable automatic cache clearing
) do |import_maps|
  import_map = AssetPipeline::ImportMap.new("application", Path["/javascript"])
  import_maps << import_map
end
```

**Before (Manual Cache Clearing):**
```crystal
JS_OUTPUT_PATH = Path["public/javascript"]

front_loader = AssetPipeline::FrontLoader.new(
  js_source_path: Path["src/javascript"], 
  js_output_path: JS_OUTPUT_PATH
) do |import_maps|
  import_map = AssetPipeline::ImportMap.new("application", Path["/javascript"])
  import_maps << import_map
  
  # Manual cache clearing required
  FileUtils.rm_rf(JS_OUTPUT_PATH)
end
```

**Benefits:**
- ✅ Eliminates the need for manual `FileUtils.rm_rf` calls
- ✅ Cache is cleared only once per `FrontLoader` instance
- ✅ Prevents accumulation of old cached files
- ✅ Enabled by default for better developer experience

**When automatic cache clearing is ideal (default behavior):**
- During development when files change frequently
- In CI/CD pipelines to ensure fresh builds
- When you want to prevent cache bloat
- General usage for cleaner asset management

**When to disable `clear_cache_upon_change: false`:**
- When troubleshooting cache-related issues
- In specific production scenarios where you manage cache clearing elsewhere
- When you need to preserve existing cached files for debugging

## Integration Guide

### Step 1: Add to shard.yml

```yaml
dependencies:
  asset_pipeline:
    github: amberframework/asset_pipeline
    version: ~> 0.36.0
```

### Step 2: Create an Initializer

Create `config/initializers/asset_pipeline.cr`:

```crystal
require "asset_pipeline"

# Initialize the FrontLoader with your paths
FRONT_LOADER = AssetPipeline::FrontLoader.new(
  js_source_path: Path["src/javascript"],
  js_output_path: Path["public/javascript"]
) do |import_maps|
  # Create your import map
  import_map = AssetPipeline::ImportMap.new("application", Path["/javascript"])

  # Add external CDN imports (Stimulus, Alpine, etc.)
  import_map.add_import("@hotwired/stimulus", "https://unpkg.com/@hotwired/stimulus/dist/stimulus.js")
  import_map.add_import("@hotwired/turbo", "https://unpkg.com/@hotwired/turbo@7.3.0/dist/turbo.es2017-esm.js")

  import_maps << import_map
end
```

### Step 3: Directory Structure

Create the following directory structure:

```
src/
  javascript/
    controllers/           # Stimulus controllers
      hello_controller.js
      form_controller.js
    application.js         # Main entry point
public/
  javascript/              # Output directory (auto-generated)
```

### Step 4: Create Application Entry Point

Create `src/javascript/application.js`:

```javascript
import { Application } from "@hotwired/stimulus"
import HelloController from "./controllers/hello_controller.js"

const application = Application.start()
application.register("hello", HelloController)
```

### Step 5: Include in Layout

Add the import map to your layout file:

**For Slang templates (`src/views/layouts/application.slang`):**
```slang
doctype html
html
  head
    == FRONT_LOADER.render_import_map("application")
    script type="module" src="/javascript/application.js"
  body
    == content
```

**For ECR templates (`src/views/layouts/application.ecr`):**
```erb
<!DOCTYPE html>
<html>
<head>
  <%= FRONT_LOADER.render_import_map("application") %>
  <script type="module" src="/javascript/application.js"></script>
</head>
<body>
  <%= content %>
</body>
</html>
```

### Step 6: Write a Stimulus Controller

Create `src/javascript/controllers/hello_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output"]

  greet() {
    this.outputTarget.textContent = "Hello from Stimulus!"
  }
}
```

### Step 7: Use in Views

```slang
div data-controller="hello"
  button data-action="click->hello#greet" Click me
  span data-hello-target="output"
```

## Amber V2 Integration

For Amber V2 applications, the Asset Pipeline replaces the need for Webpack or npm. Here's the typical setup:

1. **No npm required** - Uses native ESM modules
2. **CDN-based imports** - External libraries via import maps
3. **Automatic caching** - Built-in cache management
4. **Hot reload compatible** - Works with `amber watch`

### Recommended Dependencies for Amber V2

```yaml
dependencies:
  amber:
    github: crimson-knight/amber
    branch: master
  asset_pipeline:
    github: amberframework/asset_pipeline
    version: ~> 0.36.0
```

## Troubleshooting

### Import Map Not Rendering

Ensure the FrontLoader is initialized before rendering:

```crystal
# In config/initializers/asset_pipeline.cr
FRONT_LOADER = AssetPipeline::FrontLoader.new(...)

# In layout
== FRONT_LOADER.render_import_map("application")
```

### JavaScript Files Not Found

1. Check that source files are in `src/javascript/`
2. Verify the output path exists: `public/javascript/`
3. Restart the server after adding new files

### Module Not Found Errors

Ensure your import statements use the correct paths:

```javascript
// Correct - relative path from file
import HelloController from "./controllers/hello_controller.js"

// Correct - from import map
import { Controller } from "@hotwired/stimulus"
```

### Cache Issues

The Asset Pipeline clears cache automatically by default. To manually clear:

```crystal
# Create a new FrontLoader instance (triggers cache clear)
FRONT_LOADER = AssetPipeline::FrontLoader.new(...)
```

## Development

Thank you for your interest in contributing! Please join the Amber [Discord](https://discord.gg/JKCczAEh4D) to get the most up to date information.

If you're interested in contributing, please check out the open github issues and then ask about them in the discord group to see if anyone has made any attempts or has additional information about the issue.

## Contributing

1. Fork it (<https://github.com/your-github-user/asset_pipeline/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Seth Tucker](https://github.com/crimson-knight) - creator and maintainer
