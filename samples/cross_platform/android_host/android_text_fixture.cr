module AndroidTextFixture
  INITIAL = "A\0雪 😀 e\u0301 👩🏽‍💻 مرحبا"
  @@text = INITIAL
  @@submitted = ""
  @@submits = 0
  @@multiline = "Line one\n雪 😀"

  private def self.label(text : String, id : String)
    label = UI::Label.new(text)
    label.test_id = id
    label.number_of_lines = 0
    label
  end

  def self.build : UI::View
    root = UI::VStack.new(8.0, UI::Alignment::Leading)
    root << label(INITIAL, "unicode-heading")
    field = UI::TextField.new("名前 😀", text: @@text) { |value| @@text = value }
    field.on_submit = ->(value : String) { @@submitted = value; @@submits += 1; nil }
    field.test_id = "unicode-field"
    root << field
    root << label(@@text, "unicode-state")
    root << label("valid=#{@@text.valid_encoding?} bytes=#{@@text.bytesize}", "unicode-validity")
    root << label(@@submitted, "unicode-submitted")
    root << label("Submits: #{@@submits}", "unicode-submits")
    multiline = UI::TextEditor.new("Notes 雪 😀") { |value| @@multiline = value }
    multiline.text = @@multiline
    multiline.test_id = "unicode-multiline"
    root << multiline
    readonly = UI::TextEditor.new("Read only")
    readonly.text = "Read only 雪 😀"
    readonly.is_editable = false
    readonly.test_id = "unicode-readonly"
    root << readonly
    root
  end
end

# Showcase-only contract for the public Crystal JString/HashMap wrappers.
fun crystal_android_text_fixture_collections(env : Void*) : Void*
  source = "key\0雪😀"
  128.times do
    java_string = UI::JNI::JString.from_string(env, source)
    begin
      copied = java_string.to_string
      raise "JNI string lost UTF-8 content" unless copied == source && copied.valid_encoding?
      raise "JNI string length is not UTF-16 units" unless java_string.length == 7
    ensure
      java_string.delete_local
    end
  end
  UI::JNI.hashmap_from_strings(env, {source => "value\0e\u0301👩🏽‍💻"})
  rescue error
    UI::Android::Application.log_exception(error)
    Pointer(Void).null
end
