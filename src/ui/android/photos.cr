lib LibAndroidPhotos
  fun android_host_photo_available(source : Int32) : Int32
  fun android_host_photo_begin(source : Int32, max_dimension : Int32, quality : Int32) : Int32
  fun android_host_photo_state : Int32
  fun android_host_photo_byte_count : Int32
  fun android_host_photo_copy_bytes(buffer : UInt8*, capacity : Int32) : Int32
  fun android_host_photo_dimension(which : Int32) : Int32
  fun android_host_photo_error(buffer : UInt8*, capacity : Int32) : Int32
  fun android_host_photo_reset
end

# A photo from the library or the camera, as JPEG bytes the application
# polls for on its host tick, the same shape as the iOS photo bridge: `begin`
# presents the picker, `state` says where it is, `take` hands over the bytes
# once, `reset` clears the way for the next pick.
module UI::Android::Photos
  MAX_BYTES = 10 * 1024 * 1024

  enum Source
    Library = 0
    Camera  = 1
  end

  enum State
    Idle      = 0
    Active    = 1
    Ready     = 2
    Cancelled = 3
    Error     = 4
  end

  def self.available?(source : Source) : Bool
    LibAndroidPhotos.android_host_photo_available(source.value) == 1
  end

  # Presents the picker for the source; the result is collected later through
  # `state` and `take`. False when a pick is active, the source is unavailable
  # or the platform refused.
  def self.begin(source : Source, max_dimension : Int32 = 2000, jpeg_quality : Float64 = 0.8) : Bool
    raise ArgumentError.new("Android photo dimension must be between 64 and 8192") unless 64 <= max_dimension <= 8192
    raise ArgumentError.new("Android photo quality must be between 0 and 1") unless 0.0 < jpeg_quality <= 1.0
    LibAndroidPhotos.android_host_photo_begin(source.value, max_dimension, (jpeg_quality * 100).round.to_i.clamp(1, 100)) == 1
  end

  def self.state : State
    State.from_value?(LibAndroidPhotos.android_host_photo_state) || State::Error
  end

  # The encoded photo while the state is Ready, else nil.
  def self.take : Bytes?
    size = LibAndroidPhotos.android_host_photo_byte_count
    return nil if size <= 0 || size > MAX_BYTES
    buffer = Bytes.new(size)
    copied = LibAndroidPhotos.android_host_photo_copy_bytes(buffer.to_unsafe, buffer.size)
    copied == size ? buffer : nil
  end

  def self.width : Int32
    LibAndroidPhotos.android_host_photo_dimension(0)
  end

  def self.height : Int32
    LibAndroidPhotos.android_host_photo_dimension(1)
  end

  def self.error_message : String
    buffer = Bytes.new(512)
    length = LibAndroidPhotos.android_host_photo_error(buffer.to_unsafe, buffer.size)
    text = length > 0 ? String.new(buffer[0, length]) : ""
    text.empty? ? "the photo could not be read" : text
  end

  def self.reset : Nil
    LibAndroidPhotos.android_host_photo_reset
  end
end
