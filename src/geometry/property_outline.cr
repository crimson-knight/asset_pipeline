require "json"

module AssetPipeline
  # Portable, dependency-free service-area validation. This is not a cadastral
  # or surveying tool. Consumers MUST recompute; client measurements are hints.
  module PropertyOutline
    SCHEMA         = "ap.property-outline.v1"
    METHOD         = "spherical_cylindrical_equal_area_v1"
    EARTH_RADIUS_M = 6_371_008.8
    MAX_HOLES      =          16
    MAX_VERTICES   =         512 # excludes the repeated closing coordinate
    MAX_EXTENT_M   =     5_000.0 # maximum projected bounding-box diagonal
    MAX_BYTES      =     131_072
    EPSILON_M      =   0.000_001

    class Invalid < ArgumentError
    end

    record Coordinate, longitude : Float64, latitude : Float64 do
      def to_json(json : JSON::Builder)
        json.array { json.number(longitude); json.number(latitude) }
      end
    end

    record Ring, id : String, points : Array(Coordinate)
    record Measurement, gross_area_m2 : Float64, excluded_area_m2 : Float64, net_area_m2 : Float64
    private record XY, x : Float64, y : Float64

    class Outline
      getter revision : Int64
      getter imagery : String
      getter measurement : Measurement

      def rings : Array(Ring)
        @rings.map { |r| Ring.new(r.id, r.points.dup) }
      end

      def initialize(@rings : Array(Ring), @revision : Int64 = 0_i64, @imagery : String = "hybrid")
        raise Invalid.new("Revision must be nonnegative") if @revision < 0
        raise Invalid.new("Choose satellite or hybrid imagery") unless {"satellite", "hybrid"}.includes?(@imagery)
        # Own the coordinates so a caller cannot mutate a validated result.
        @rings = @rings.map { |r| Ring.new(r.id, r.points.dup) }
        @measurement = PropertyOutline.validate(@rings)
      end

      def to_json(json : JSON::Builder)
        json.object do
          json.field "schema", SCHEMA
          json.field "revision", revision
          json.field "source", "user_drawn_map"
          json.field "imagery", imagery
          json.field "units", "m2"
          json.field "ring_ids", rings.map(&.id)
          json.field "geometry" do
            json.object do
              json.field "type", "Polygon"
              json.field "coordinates" do
                json.array do
                  rings.each do |ring|
                    json.array do
                      ring.points.each(&.to_json(json))
                      ring.points.first.to_json(json)
                    end
                  end
                end
              end
            end
          end
          json.field "measurement" do
            json.object do
              json.field "method", METHOD
              json.field "earth_radius_m", EARTH_RADIUS_M
              json.field "gross_area_m2", measurement.gross_area_m2
              json.field "excluded_area_m2", measurement.excluded_area_m2
              json.field "net_area_m2", measurement.net_area_m2
            end
          end
          json.field "assumptions", [
            "Approximate user-drawn service area; not property boundaries or a survey.",
            "Imagery age and positional accuracy are unknown.",
            "Spherical equal-area projection with straight projected edges; terrain slope is not measured.",
          ]
        end
      end
    end

    # Ignores client measurement/price/entitlement metadata; validates geometry
    # and emits canonical derived values. JSON depth/length are bounded first.
    def self.parse(payload : String) : Outline
      raise Invalid.new("Outline payload is too large") if payload.bytesize > MAX_BYTES
      bound_json_depth(payload)
      data = JSON.parse(payload).as_h
      raise Invalid.new("Unsupported outline schema") unless data["schema"].as_s == SCHEMA
      raise Invalid.new("Unsupported outline source") unless data["source"].as_s == "user_drawn_map"
      raise Invalid.new("Outline units must be m2") unless data["units"].as_s == "m2"
      geometry = data["geometry"].as_h
      raise Invalid.new("Expected a GeoJSON Polygon") unless geometry["type"].as_s == "Polygon"
      coordinates = geometry["coordinates"].as_a
      ids = data["ring_ids"].as_a
      raise Invalid.new("Each ring needs a stable identifier") unless ids.size == coordinates.size
      raise Invalid.new("Use one lawn outline and at most #{MAX_HOLES} exclusions") unless (1..MAX_HOLES + 1).includes?(coordinates.size)
      total = 0
      rings = coordinates.map_with_index do |raw, i|
        values = raw.as_a
        total += values.size - 1
        raise Invalid.new("Use at most #{MAX_VERTICES} vertices") if total > MAX_VERTICES
        raise Invalid.new("Add at least three points around each area before saving") if values.size < 4
        points = values.map do |pair|
          numbers = pair.as_a
          raise Invalid.new("Coordinates must be longitude, latitude pairs") unless numbers.size == 2
          Coordinate.new(number(numbers[0]), number(numbers[1]))
        end
        raise Invalid.new("GeoJSON rings must be closed") unless points.first == points.last
        Ring.new(ids[i].as_s, points[0...-1])
      end
      Outline.new(rings, data["revision"].as_i64, data["imagery"].as_s)
    rescue ex : Invalid
      raise ex
    rescue ex : JSON::ParseException | TypeCastError | KeyError | OverflowError
      raise Invalid.new("Malformed outline payload")
    end

    private def self.bound_json_depth(payload : String)
      depth = 0
      quoted = false
      escaped = false
      payload.each_byte do |byte|
        if quoted
          if escaped
            escaped = false
          elsif byte == 92
            escaped = true
          elsif byte == 34
            quoted = false
          end
        elsif byte == 34
          quoted = true
        elsif byte == 91 || byte == 123
          depth += 1
          raise Invalid.new("Outline payload is nested too deeply") if depth > 12
        elsif byte == 93 || byte == 125
          depth -= 1
        end
      end
    end

    private def self.number(value : JSON::Any) : Float64
      raw = value.raw
      case raw
      when Float64 then raw
      when Int64   then raw.to_f64
      else              raise Invalid.new("Coordinates must be finite numbers")
      end
    end

    def self.validate(rings : Array(Ring)) : Measurement
      raise Invalid.new("Use one lawn outline and at most #{MAX_HOLES} exclusions") unless (1..MAX_HOLES + 1).includes?(rings.size)
      raise Invalid.new("Use at most #{MAX_VERTICES} vertices") if rings.sum(&.points.size) > MAX_VERTICES
      ids = rings.map(&.id)
      raise Invalid.new("Ring identifiers must be unique") unless ids.uniq.size == ids.size
      ids.each do |id|
        raise Invalid.new("Invalid ring identifier") unless id.matches?(/\A[a-zA-Z0-9_-]{1,64}\z/)
      end
      points = rings.flat_map(&.points)
      rings.each do |ring|
        raise Invalid.new("Add at least three points around each area before saving") if ring.points.size < 3
        raise Invalid.new("Remove repeated points from the outline") if ring.points.uniq.size != ring.points.size
      end
      points.each do |p|
        unless p.longitude.finite? && p.latitude.finite? && (-180.0..180.0).includes?(p.longitude) && (-85.0..85.0).includes?(p.latitude)
          raise Invalid.new("Use finite WGS84 coordinates between 85 degrees south and north")
        end
      end
      raise Invalid.new("Outlines crossing the antimeridian are not supported") if points.max_of(&.longitude) - points.min_of(&.longitude) > 180
      origin = points.first
      cos_lat = Math.cos(origin.latitude * Math::PI / 180)
      projected = rings.map do |r|
        r.points.map { |p| XY.new((p.longitude - origin.longitude) * Math::PI / 180 * EARTH_RADIUS_M * cos_lat, (p.latitude - origin.latitude) * Math::PI / 180 * EARTH_RADIUS_M) }
      end
      all_xy = projected.flatten
      width = all_xy.max_of(&.x) - all_xy.min_of(&.x)
      height = all_xy.max_of(&.y) - all_xy.min_of(&.y)
      raise Invalid.new("Outline exceeds the 5 km local-property extent") if Math.sqrt(width * width + height * height) > MAX_EXTENT_M
      projected.each do |ring|
        ring.each_with_index do |a, i|
          b = ring[(i + 1) % ring.size]
          raise Invalid.new("Vertices are too close together") if distance_squared(a, b) <= EPSILON_M ** 2
          c = ring[(i + 2) % ring.size]
          raise Invalid.new("Remove collinear or doubled-back vertices") if cross(a, b, c).abs <= EPSILON_M ** 2
          ((i + 1)...ring.size).each do |j|
            next if j == i + 1 || (i == 0 && j == ring.size - 1)
            if intersects?(a, b, ring[j], ring[(j + 1) % ring.size])
              raise Invalid.new("Outline edges must not cross or touch")
            end
          end
        end
      end
      outer = projected.first
      projected[1..].each_with_index do |hole, index|
        raise Invalid.new("Exclusions must be strictly inside the lawn outline") unless inside?(hole.first, outer) && !rings_intersect?(outer, hole)
        projected[1...index + 1].each do |other|
          if rings_intersect?(hole, other) || inside?(hole.first, other) || inside?(other.first, hole)
            raise Invalid.new("Exclusions must not overlap, contain, or touch one another")
          end
        end
      end
      areas = rings.map { |r| area(r.points) }
      raise Invalid.new("Each ring must enclose a measurable area") if areas.any? { |v| v < 0.01 }
      excluded = areas[1..].sum
      Measurement.new(areas.first, excluded, areas.first - excluded)
    end

    private def self.area(points : Array(Coordinate)) : Float64
      origin = points.first
      lambda0 = origin.longitude * Math::PI / 180
      sin_phi0 = Math.sin(origin.latitude * Math::PI / 180)
      projected = points.map { |p| XY.new(p.longitude * Math::PI / 180 - lambda0, Math.sin(p.latitude * Math::PI / 180) - sin_phi0) }
      sum = 0.0
      projected.each_with_index do |a, i|
        b = projected[(i + 1) % projected.size]
        sum += a.x * b.y - b.x * a.y
      end
      sum.abs * EARTH_RADIUS_M ** 2 / 2
    end

    private def self.distance_squared(a : XY, b : XY)
      (a.x - b.x) ** 2 + (a.y - b.y) ** 2
    end

    private def self.cross(a : XY, b : XY, c : XY)
      (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    end

    private def self.on_segment?(p : XY, a : XY, b : XY)
      cross(a, b, p).abs <= EPSILON_M ** 2 && p.x >= {a.x, b.x}.min - EPSILON_M && p.x <= {a.x, b.x}.max + EPSILON_M && p.y >= {a.y, b.y}.min - EPSILON_M && p.y <= {a.y, b.y}.max + EPSILON_M
    end

    private def self.intersects?(a : XY, b : XY, c : XY, d : XY)
      return true if on_segment?(a, c, d) || on_segment?(b, c, d) || on_segment?(c, a, b) || on_segment?(d, a, b)
      cross(a, b, c) * cross(a, b, d) < 0 && cross(c, d, a) * cross(c, d, b) < 0
    end

    private def self.rings_intersect?(first : Array(XY), second : Array(XY))
      first.each_with_index.any? do |a, i|
        second.each_with_index.any? { |b, j| intersects?(a, first[(i + 1) % first.size], b, second[(j + 1) % second.size]) }
      end
    end

    private def self.inside?(point : XY, ring : Array(XY))
      inside = false
      ring.each_with_index do |a, i|
        b = ring[(i + 1) % ring.size]
        return false if on_segment?(point, a, b)
        if (a.y > point.y) != (b.y > point.y) && point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x
          inside = !inside
        end
      end
      inside
    end
  end
end
