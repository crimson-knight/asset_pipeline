require "../src/asset_pipeline/android_assets"

unless ARGV.size == 3
  STDERR.puts "Usage: compile_android_assets <project-root> <project-relative-catalog> <generated-output>"
  exit 2
end

begin
  AssetPipeline::AndroidAssets::Compiler.new(ARGV[0]).compile(ARGV[1], ARGV[2])
  puts "Compiled Android image catalog: #{ARGV[2]}"
rescue error
  STDERR.puts "Android asset compilation failed: #{error.message}"
  exit 1
end
