require "yaml"
require "json"
require "xml"
require "digest/sha256"
require "file_utils"

# Host-side packaging only; never imported by the embedded Android runtime.
module AssetPipeline::AndroidAssets
  FORMAT = "asset-pipeline-android-images-v1"

  class Image
    include YAML::Serializable
    include YAML::Serializable::Strict
    property source : String = ""
    property dark_source : String? = nil
    property density : String = "nodpi"
  end

  class Catalog
    include YAML::Serializable
    include YAML::Serializable::Strict
    property schema_version : Int32 = 1
    property images : Hash(String, Image) = {} of String => Image

    def initialize
    end
  end

  record Output, path : String, data : String, source : String? = nil

  class Compiler
    MAX_FILE  = 8 * 1024 * 1024
    MAX_TOTAL = 64 * 1024 * 1024
    DENSITIES = %w[nodpi ldpi mdpi hdpi xhdpi xxhdpi xxxhdpi]
    getter root : String

    def initialize(root : String)
      @requested_root = File.expand_path(root)
      @root = File.realpath(root)
    end

    def compile(manifest : String, destination : String) : Nil
      manifest = project_path(manifest)
      raise ArgumentError.new("Image catalog must be a regular file") unless File.file?(manifest)
      raise ArgumentError.new("Image catalog is too large") if File.size(manifest) > 1024 * 1024
      manifest_data = File.read(manifest)
      raise ArgumentError.new("Image catalog is too large") if manifest_data.bytesize > 1024 * 1024
      catalog = Catalog.from_yaml(manifest_data)
      raise ArgumentError.new("Unsupported image catalog schema_version") unless catalog.schema_version == 1
      raise ArgumentError.new("Image catalog supports at most 512 images") if catalog.images.size > 512
      outputs = [] of Output
      total = 0_i64
      index = String.build do |io|
        io << "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<image-catalog version=\"1\">\n"
        catalog.images.keys.sort.each do |name|
          unless name.valid_encoding? && !name.strip.empty? && name.bytesize <= 1024 && !name.starts_with?('@') && !name.starts_with?('?') && !name.matches?(/[\x00-\x1f\x7f]/)
            raise ArgumentError.new("Invalid logical image name")
          end
          image = catalog.images[name]
          raise ArgumentError.new("Invalid image density for #{name}") unless DENSITIES.includes?(image.density)
          resource = "ap_image_#{Digest::SHA256.hexdigest(name)[0, 32]}"
          { {image.source, false}, {image.dark_source, true} }.each do |source, dark|
            next unless source
            path = project_path(source)
            raise ArgumentError.new("Image source must be a regular file: #{source}") unless File.file?(path)
            size = File.size(path)
            raise ArgumentError.new("Image exceeds 8 MiB: #{source}") unless 0 < size <= MAX_FILE
            total += size
            raise ArgumentError.new("Image catalog exceeds 64 MiB") if total > MAX_TOTAL
            extension = File.extname(path).downcase
            unless {".png", ".jpg", ".jpeg", ".webp", ".xml"}.includes?(extension)
              raise ArgumentError.new("Unsupported Android image #{source}; use PNG, JPEG, WebP or Android VectorDrawable XML (SVG requires an explicit Android export)")
            end
            raise ArgumentError.new("Nine-patch images require a separate stretch-region contract") if source.ends_with?(".9.png")
            data = File.read(path)
            raise ArgumentError.new("Image changed while being read: #{source}") unless data.bytesize == size
            validate_vector(data, source) if extension == ".xml"
            extension = ".jpg" if extension == ".jpeg"
            qualifiers = dark ? "night-#{image.density}" : image.density
            outputs << Output.new("res/drawable-#{qualifiers}/#{resource}#{extension}", data, source)
          end
          io << "  <image name=\"#{escape(name)}\" drawable=\"@drawable/#{resource}\" />\n"
        end
        io << "</image-catalog>\n"
      end
      raise ArgumentError.new("Image resource-name collision") unless outputs.map(&.path).uniq.size == outputs.size
      outputs << Output.new("res/xml/ap_image_catalog.xml", index)
      provenance = JSON.build do |json|
        json.object do
          json.field "format", FORMAT
          json.field "catalog_sha256", Digest::SHA256.hexdigest(manifest_data)
          json.field "files" do
            json.array do
              outputs.sort_by(&.path).each do |output|
                json.object do
                  json.field "path", output.path
                  json.field "source", output.source
                  json.field "sha256", Digest::SHA256.hexdigest(output.data)
                  json.field "bytes", output.data.bytesize
                end
              end
            end
          end
        end
      end
      outputs << Output.new("manifest.json", provenance + "\n")
      publish(destination, outputs)
    end

    private def validate_vector(data : String, source : String) : Nil
      raise ArgumentError.new("Vector XML is too large: #{source}") if data.bytesize > 1024 * 1024
      raise ArgumentError.new("Invalid vector XML: #{source}") unless data.valid_encoding? && !data.includes?("<!DOCTYPE")
      document = XML.parse(data, options: XML::ParserOptions::NONET)
      root = document.root || raise ArgumentError.new("Missing vector root: #{source}")
      raise ArgumentError.new("Only Android VectorDrawable XML is supported: #{source}") unless root.name == "vector"
      # AAPT2 validates the actual vector grammar and referenced app resources.
    end

    private def escape(value : String) : String
      value.gsub('&', "&amp;").gsub('"', "&quot;").gsub('<', "&lt;").gsub('>', "&gt;")
    end

    private def project_path(relative : String) : String
      unless relative.valid_encoding? && !relative.empty? && !Path[relative].absolute? &&
             !relative.matches?(/[\x00-\x1f\x7f\\]/) && relative.split('/').all? { |part| !{"", ".", ".."}.includes?(part) }
        raise ArgumentError.new("Asset paths must be explicit project-relative paths")
      end
      path = File.join(@root, relative)
      reject_symlinks(path)
      path
    end

    private def reject_symlinks(path : String) : Nil
      current = @root
      Path[path].relative_to(@root).parts.each do |part|
        current = File.join(current, part)
        raise ArgumentError.new("Asset input/output paths cannot follow symlinks") if File.symlink?(current)
      end
    end

    private def publish(destination : String, outputs : Array(Output)) : Nil
      destination = File.expand_path(destination)
      # macOS /var and /tmp aliases may differ from the canonical project root.
      # Only normalize the root alias supplied by the caller, never symlinks
      # inside the application-owned input/output tree.
      if destination.starts_with?(@requested_root + "/")
        destination = File.join(@root, Path[destination].relative_to(@requested_root).to_s)
      end
      unless destination.starts_with?(@root + "/") && destination.includes?("/build/") && File.basename(destination) == "assetPipelineImages"
        raise ArgumentError.new("Image output must be a project build directory named assetPipelineImages")
      end
      reject_symlinks(destination)
      # Gradle creates declared output directories before invoking Exec. An
      # empty directory contains no user-owned data; every nonempty tree still
      # requires the complete, unchanged compiler ledger below.
      if File.exists?(destination) && !(File.directory?(destination) && Dir.empty?(destination))
        marker = File.join(destination, "manifest.json")
        unless !File.symlink?(marker) && File.file?(marker) && File.size(marker) <= 1024 * 1024
          raise ArgumentError.new("Refusing to replace an unowned image output directory")
        end
        marker_data = File.read(marker)
        raise ArgumentError.new("Image output ledger is too large") if marker_data.bytesize > 1024 * 1024
        output_manifest = JSON.parse(marker_data)
        unless output_manifest["format"]?.try(&.as_s?) == FORMAT
          raise ArgumentError.new("Refusing to replace an unowned image output directory")
        end
        # Never erase handwritten additions or symlinks in a generated tree.
        ledger = output_manifest["files"].as_a
        recorded = ledger.map { |file| file["path"].as_s }.sort
        unless recorded.size <= 1025 && recorded.uniq.size == recorded.size && recorded.all? { |path| path.starts_with?("res/") && !path.matches?(/[\x00-\x1f\x7f\\]/) && path.split('/').size <= 4 && path.split('/').all? { |part| !{"", ".", ".."}.includes?(part) } }
          raise ArgumentError.new("Invalid image output ledger paths")
        end
        expected_directories = recorded.flat_map do |path|
          parents = [] of String
          parent = Path[path].parent
          until parent.to_s == "."
            parents << parent.to_s
            parent = parent.parent
          end
          parents
        end.uniq
        actual = Dir.glob(File.join(destination, "**", "*"), match: File::MatchOptions.glob_default | File::MatchOptions::DotFiles)
        actual.each { |path| raise ArgumentError.new("Generated image output contains a symlink") if File.symlink?(path) }
        actual.reject! do |path|
          if File.directory?(path)
            unless expected_directories.includes?(Path[path].relative_to(destination).to_s)
              raise ArgumentError.new("Generated image output contains an unowned directory")
            end
            true
          else
            false
          end
        end
        names = actual.map { |path| Path[path].relative_to(destination).to_s }.reject { |path| path == "manifest.json" }.sort
        raise ArgumentError.new("Generated image output contains unowned files") unless names == recorded
        ledger.each do |file|
          path = File.join(destination, file["path"].as_s)
          unless File.size(path) == file["bytes"].as_i64 && Digest::SHA256.hexdigest(File.read(path)) == file["sha256"].as_s
            raise ArgumentError.new("Generated image output was modified outside the compiler")
          end
        end
      end
      Dir.mkdir_p(File.dirname(destination))
      staging = "#{destination}.pending-#{Random.rand(UInt64).to_s(16)}"
      retired = "#{destination}.retired-#{Random.rand(UInt64).to_s(16)}"
      Dir.mkdir(staging, 0o700)
      begin
        outputs.each do |output|
          path = File.join(staging, output.path)
          Dir.mkdir_p(File.dirname(path))
          File.write(path, output.data)
        end
        File.rename(destination, retired) if File.exists?(destination)
        begin
          File.rename(staging, destination)
        rescue error
          File.rename(retired, destination) if File.exists?(retired)
          raise error
        end
        FileUtils.rm_rf(retired) if File.exists?(retired)
      ensure
        FileUtils.rm_rf(staging) if File.exists?(staging)
      end
    end
  end
end
