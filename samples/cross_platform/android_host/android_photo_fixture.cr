# Photo picker contract. The host presents the system photo picker or the
# camera, decodes the result off the main looper, fits its longest edge to
# the requested dimension, honors the EXIF orientation and encodes JPEG; the
# application polls the outcome on its host tick, the way the iOS bridge is
# polled. The fixture prints the picker's state, the encoded size and pixel
# dimensions, which sources are available and the last error, and offers a
# button per source and a reset. A device test feeds a photo through the
# delivery path and checks the numbers, and launches the real picker and
# cancels it. The snapshot is a plain record so the host spec builds it.
module AndroidPhotoFixture
  record Snapshot,
    state : String,
    bytes : Int32,
    width : Int32,
    height : Int32,
    library : Bool,
    camera : Bool,
    error : String

  def self.build(snapshot : Snapshot, library : Proc(Nil), camera : Proc(Nil), reset : Proc(Nil)) : UI::View
    root = UI::VStack.new(8.0, UI::Alignment::Leading)
    root.test_id = "photo-page"
    root.padding = UI::EdgeInsets.new(top: 12.0, trailing: 18.0, bottom: 12.0, leading: 18.0)
    heading = UI::Label.new("Native photos")
    heading.accessibility_role = :header
    heading.test_id = "photo-heading"
    root << heading
    root << label("photo-state", "State #{snapshot.state}")
    root << label("photo-bytes", "Bytes #{snapshot.bytes}")
    root << label("photo-size", "Size #{snapshot.width}x#{snapshot.height}")
    root << label("photo-available", "Library #{snapshot.library} camera #{snapshot.camera}")
    root << label("photo-error", "Error #{snapshot.error}")
    root << button("photo-library", "Pick from library", library)
    root << button("photo-camera", "Take photo", camera)
    root << button("photo-reset", "Reset", reset)
    root
  end

  private def self.label(id : String, text : String) : UI::Label
    label = UI::Label.new(text)
    label.test_id = id
    label
  end

  private def self.button(id : String, title : String, action : Proc(Nil)) : UI::Button
    button = UI::Button.new(title) { action.call; nil }
    button.test_id = id
    button
  end
end
