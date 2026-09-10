require "spec"
require "../src/asset_pipeline/android_assets"

private def with_image_project(&)
  root = File.tempname("ap-image-project")
  Dir.mkdir_p(File.join(root, "src/assets"))
  Dir.mkdir_p(File.join(root, "config"))
  begin
    yield root, AssetPipeline::AndroidAssets::Compiler.new(root), File.join(root, "build/generated/assetPipelineImages")
  ensure
    FileUtils.rm_rf(root)
  end
end

private def write_catalog(root, contents)
  File.write(File.join(root, "config/android_assets.yml"), contents)
end

private def vector
  %(<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="80dp" android:height="40dp" android:viewportWidth="80" android:viewportHeight="40"><path android:fillColor="#FF0000" android:pathData="M0,0L80,0L80,40L0,40Z"/></vector>)
end

describe AssetPipeline::AndroidAssets::Compiler do
  it "rejects tampered ledger paths before traversing parents or touching output" do
    with_image_project do |root, compiler, output|
      write_catalog(root, "images: {}\n")
      compiler.compile("config/android_assets.yml", output)
      marker = File.join(output, "manifest.json")
      original = File.read(marker)
      ["/", "/tmp/outside", "res/../../outside", "res//empty", "res/./dot", "res\\backslash", "res/a/b/c/d"].each do |invalid|
        manifest = JSON.parse(original)
        manifest["files"][0].as_h["path"] = JSON::Any.new(invalid)
        File.write(marker, manifest.to_json)
        expect_raises(ArgumentError, /Invalid image output ledger paths/) { compiler.compile("config/android_assets.yml", output) }
        File.exists?(File.join(output, "res/xml/ap_image_catalog.xml")).should be_true
      end
    end
  end

  it "preserves handwritten empty directories in a generated tree" do
    with_image_project do |root, compiler, output|
      write_catalog(root, "images: {}\n")
      compiler.compile("config/android_assets.yml", output)
      Dir.mkdir(File.join(output, "my-directory"))
      expect_raises(ArgumentError, /unowned directory/) { compiler.compile("config/android_assets.yml", output) }
      File.directory?(File.join(output, "my-directory")).should be_true
    end
  end

  it "accepts an empty Gradle-created output directory but preserves hidden additions" do
    with_image_project do |root, compiler, output|
      write_catalog(root, "images: {}\n")
      Dir.mkdir_p(output)
      compiler.compile("config/android_assets.yml", output)
      File.write(File.join(output, ".keep"), "user")
      expect_raises(ArgumentError, /unowned files/) { compiler.compile("config/android_assets.yml", output) }
      File.read(File.join(output, ".keep")).should eq("user")
    end
  end

  it "emits deterministic sorted resources, dark variants and exact content provenance" do
    with_image_project do |root, compiler, output|
      File.write(File.join(root, "src/assets/light.xml"), vector)
      File.write(File.join(root, "src/assets/dark.xml"), vector.gsub("#FF0000", "#0000FF"))
      write_catalog(root, "schema_version: 1\nimages:\n  \"brands/雪 😀\":\n    source: src/assets/light.xml\n    dark_source: src/assets/dark.xml\n  logo:\n    source: src/assets/light.xml\n")
      compiler.compile("config/android_assets.yml", output)
      before = File.read(File.join(output, "manifest.json"))
      index = XML.parse(File.read(File.join(output, "res/xml/ap_image_catalog.xml")))
      index.xpath_nodes("//image").map { |node| node["name"] }.should eq(["brands/雪 😀", "logo"])
      Dir.glob(File.join(output, "res/drawable-night-nodpi/*")).size.should eq(1)
      ledger = JSON.parse(before)["files"].as_a
      ledger.each do |file|
        data = File.read(File.join(output, file["path"].as_s))
        Digest::SHA256.hexdigest(data).should eq(file["sha256"].as_s)
        data.bytesize.should eq(file["bytes"].as_i64)
      end
      compiler.compile("config/android_assets.yml", output)
      File.read(File.join(output, "manifest.json")).should eq(before)
    end
  end

  it "replaces only compiler-owned outputs and removes stale resource variants" do
    with_image_project do |root, compiler, output|
      File.write(File.join(root, "src/assets/light.xml"), vector)
      write_catalog(root, "images:\n  logo:\n    source: src/assets/light.xml\n")
      compiler.compile("config/android_assets.yml", output)
      write_catalog(root, "images: {}\n")
      compiler.compile("config/android_assets.yml", output)
      Dir.glob(File.join(output, "res/drawable*/*")).should be_empty
      File.write(File.join(output, "handwritten.txt"), "preserve")
      expect_raises(ArgumentError, /unowned files/) { compiler.compile("config/android_assets.yml", output) }
      File.read(File.join(output, "handwritten.txt")).should eq("preserve")
    end
  end

  it "preserves the previous complete output when a catalog or source is invalid" do
    with_image_project do |root, compiler, output|
      File.write(File.join(root, "src/assets/light.xml"), vector)
      write_catalog(root, "images:\n  logo:\n    source: src/assets/light.xml\n")
      compiler.compile("config/android_assets.yml", output)
      before = File.read(File.join(output, "manifest.json"))
      ["schema_version: 2\n", "images:\n  logo:\n    source: missing.png\n", "images:\n  logo:\n    source: src/assets/light.xml\n    density: retina\n"].each do |bad|
        write_catalog(root, bad)
        expect_raises(ArgumentError) { compiler.compile("config/android_assets.yml", output) }
        File.read(File.join(output, "manifest.json")).should eq(before)
      end
      write_catalog(root, "images:\n  logo:\n    soruce: src/assets/light.xml\n")
      expect_raises(YAML::ParseException) { compiler.compile("config/android_assets.yml", output) }
    end
  end

  it "rejects traversal, absolute paths, symlink inputs and unsafe output roots" do
    with_image_project do |root, compiler, output|
      File.write(File.join(root, "src/assets/light.xml"), vector)
      File.symlink("light.xml", File.join(root, "src/assets/link.xml"))
      ["../outside.png", "/tmp/outside.png", "src//assets/light.xml", "src/assets/link.xml"].each do |source|
        write_catalog(root, "images:\n  logo:\n    source: #{source}\n")
        expect_raises(ArgumentError) { compiler.compile("config/android_assets.yml", output) }
        File.exists?(output).should be_false
      end
      write_catalog(root, "images: {}\n")
      expect_raises(ArgumentError) { compiler.compile("config/android_assets.yml", root) }
      expect_raises(ArgumentError) { compiler.compile("config/android_assets.yml", File.join(root, "src/assetPipelineImages")) }
      Dir.mkdir_p(output)
      File.write(File.join(output, "keep.txt"), "user")
      expect_raises(ArgumentError, /unowned image output/) { compiler.compile("config/android_assets.yml", output) }
      File.read(File.join(output, "keep.txt")).should eq("user")
    end
  end

  it "rejects silent format fallbacks, unsafe XML and modified generated files" do
    with_image_project do |root, compiler, output|
      {"logo.svg" => "<svg/>", "logo.xml" => "<!DOCTYPE vector><vector/>", "shape.xml" => "<shape/>", "empty.png" => ""}.each do |name, data|
        File.write(File.join(root, "src/assets", name), data)
        write_catalog(root, "images:\n  logo:\n    source: src/assets/#{name}\n")
        expect_raises(ArgumentError) { compiler.compile("config/android_assets.yml", output) }
      end
      write_catalog(root, "images: {}\n")
      compiler.compile("config/android_assets.yml", output)
      File.write(File.join(output, "res/xml/ap_image_catalog.xml"), "handwritten")
      expect_raises(ArgumentError, /modified outside/) { compiler.compile("config/android_assets.yml", output) }
    end
  end
end
