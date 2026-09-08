module UI::Android
  # The rectangle the host lays the view tree out in, in dp, and the parts of
  # the system bars and display cutout inside it that the host has not kept
  # clear itself. The host reports it before every render and again when its
  # container or the mount is laid out to a different size. A host that keeps
  # the bars clear with padding reports zero insets, an edge-to-edge host
  # reports the bars, and the keyboard never changes it. Units match iOS
  # points, so an application copies it into the metrics its views already
  # size against.
  struct Viewport
    getter width : Float64
    getter height : Float64
    getter top_inset : Float64
    getter bottom_inset : Float64
    getter left_inset : Float64
    getter right_inset : Float64
    getter density : Float64

    def initialize(@width : Float64, @height : Float64, @top_inset : Float64 = 0.0, @bottom_inset : Float64 = 0.0,
                   @left_inset : Float64 = 0.0, @right_inset : Float64 = 0.0, @density : Float64 = 1.0)
      {@width, @height, @top_inset, @bottom_inset, @left_inset, @right_inset, @density}.each do |value|
        raise ArgumentError.new("Android viewport values must be finite") unless value.finite?
      end
      raise ArgumentError.new("Android viewport must have a positive size") unless @width > 0.0 && @height > 0.0
      if @top_inset < 0.0 || @bottom_inset < 0.0 || @left_inset < 0.0 || @right_inset < 0.0
        raise ArgumentError.new("Android viewport insets must not be negative")
      end
      raise ArgumentError.new("Android viewport density must be positive") unless @density > 0.0
      if @top_inset + @bottom_inset >= @height || @left_inset + @right_inset >= @width
        raise ArgumentError.new("Android viewport insets leave no content area")
      end
    end

    # The width left once the insets the application must keep clear are spent.
    def content_width : Float64
      width - left_inset - right_inset
    end

    def content_height : Float64
      height - top_inset - bottom_inset
    end
  end
end
