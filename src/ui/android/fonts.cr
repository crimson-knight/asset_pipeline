lib LibAndroidFonts
  fun android_host_font_register(family : UInt8*, family_size : Int32, path : UInt8*, path_size : Int32) : Int32
end

# Typefaces the application bundles. A registered family name resolves for
# every `UI::Font` that names it; unregistered names fall through to
# Android's generic families and then the platform default, which is what
# an unknown name gets on iOS too.
module UI::Android::Fonts
  # Registers a TTF or OTF file inside the application's private storage
  # (the extracted bundle, the files directory) under the family name the
  # views use. False when the host refused the file: missing, outside
  # private storage, or not a font.
  def self.register(family : String, path : String) : Bool
    raise ArgumentError.new("Android font family must not be blank") if family.strip.empty?
    raise ArgumentError.new("Android font path must be absolute") unless path.starts_with?('/')
    LibAndroidFonts.android_host_font_register(family.to_unsafe, family.bytesize, path.to_unsafe, path.bytesize) == 1
  end
end
