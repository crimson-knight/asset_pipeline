require "../../../src/ui"

lib PropertyFixtureHost
  fun ap_property_fixture_saved(json : UInt8*) : Void
  fun ap_property_fixture_draft(json : UInt8*) : Void
end

lib PropertyFixtureGC
  fun set_no_dls = GC_set_no_dls(value : LibC::Int)
end

module PropertyFixture
  @@native : UI::NativeView? = nil

  def self.render(initial : String) : Void*
    map = UI::MapView.new
    map.latitude = 43.148
    map.longitude = -71.555
    map.zoom_level = 19.0
    map.minimum_height = 0.0
    map.minimum_width = 0.0
    map.test_id = "property-editor"
    map.address_label = "Synthetic lawn, Bow, New Hampshire"
    editor = UI::PropertyMapEditor.new("fixture-lawn")
    unless initial.empty?
      begin
        editor.initial_outline = AssetPipeline::PropertyOutline.parse(initial)
      rescue AssetPipeline::PropertyOutline::Invalid
        # Invalid saved local input starts an empty draft, never a trusted area.
      end
    end
    editor.on_draft_change = ->(raw : String) { PropertyFixtureHost.ap_property_fixture_draft(raw.to_unsafe); nil }
    editor.on_save = ->(outline : AssetPipeline::PropertyOutline::Outline) { raw = outline.to_json; PropertyFixtureHost.ap_property_fixture_saved(raw.to_unsafe); nil }
    map.property_editor = editor
    renderer = UI::UIKit::Renderer.new(reuse_from: @@native)
    native = renderer.render(map)
    renderer.retire_prior!(native)
    @@native = native
    native.handle.ptr!
  end
end

# The Swift entry point hides Crystal's generated C main. Initialize the GC,
# runtime and top-level constants once, before even allocating an input String.
# Runtime-only initialization leaves Float's Dragonbox cache uninitialized and
# crashes the first map-coordinate JSON serialization. argv must include argv[0].
fun ap_property_fixture_runtime_init : Int32
  GC.init
  PropertyFixtureGC.set_no_dls(1)
  Crystal.init_runtime
  program = "PropertyMeasurementFixture"
  argv = uninitialized UInt8*[2]
  argv[0] = program.to_unsafe
  argv[1] = Pointer(UInt8).null
  Crystal.main_user_code(1, argv.to_unsafe)
  1
  rescue ex
    STDERR.puts "Property fixture runtime initialization failed: #{ex.message}"
    0
end

fun ap_property_fixture_render(initial : UInt8*) : Void*
  PropertyFixture.render(String.new(initial))
end
