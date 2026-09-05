require "spec"
require "../../src/geometry/property_outline"

alias PO = AssetPipeline::PropertyOutline

private def rectangle(west = -71.0, south = 43.0, size = 0.001)
  [PO::Coordinate.new(west, south), PO::Coordinate.new(west + size, south), PO::Coordinate.new(west + size, south + size), PO::Coordinate.new(west, south + size)]
end

describe PO do
  it "passes the canonical portable server/native fixture corpus" do
    fixtures = JSON.parse(File.read("#{__DIR__}/../fixtures/property_outline_v1.json"))
    fixtures["cases"].as_a.each do |example|
      rings = example["rings"].as_a.map_with_index do |ring, index|
        points = ring.as_a[0...-1].map { |pair| PO::Coordinate.new(pair[0].as_f, pair[1].as_f) }
        PO::Ring.new("ring-#{index}", points)
      end
      if example["valid"].as_bool
        measurement = PO::Outline.new(rings).measurement
        expected = example["expected"]
        measurement.gross_area_m2.should be_close(expected["gross_area_m2"].as_f, 0.00001)
        measurement.excluded_area_m2.should be_close(expected["excluded_area_m2"].as_f, 0.00001)
        measurement.net_area_m2.should be_close(expected["net_area_m2"].as_f, 0.00001)
      else
        expect_raises(PO::Invalid) { PO::Outline.new(rings) }
      end
    end
  end

  it "measures gross, excluded and net with orientation-independent rings" do
    outer = rectangle
    hole = rectangle(-70.9998, 43.0002, 0.0002)
    outline = PO::Outline.new([PO::Ring.new("lawn", outer), PO::Ring.new("shed", hole.reverse)])
    measurement = outline.measurement
    expected = PO::EARTH_RADIUS_M ** 2 * 0.001 * Math::PI / 180 * (Math.sin(43.001 * Math::PI / 180) - Math.sin(43.0 * Math::PI / 180))
    measurement.gross_area_m2.should be_close(expected, 0.00001)
    measurement.net_area_m2.should be_close(measurement.gross_area_m2 - measurement.excluded_area_m2, 0.00001)
    PO::Outline.new([PO::Ring.new("lawn", outer.reverse), PO::Ring.new("shed", hole)]).measurement.should eq(measurement)
  end

  it "roundtrips closed WGS84 rings, stable IDs and precision without trusting areas" do
    original = PO::Outline.new([PO::Ring.new("lawn", rectangle)], 18_i64, "satellite")
    parsed = PO.parse(original.to_json)
    parsed.rings.should eq(original.rings)
    parsed.measurement.should eq(original.measurement)
    parsed.revision.should eq(18)
    json = JSON.parse(original.to_json)
    json["geometry"]["coordinates"][0].as_a.size.should eq(5)
    json["measurement"]["method"].as_s.should eq(PO::METHOD)
    json.as_h["measurement"] = JSON::Any.new("untrusted-client-value")
    PO.parse(json.to_json).measurement.should eq(original.measurement)
  end

  it "refuses crossings, degenerate rings, and repeated vertices" do
    outer = rectangle
    [[outer[0], outer[2], outer[1], outer[3]], [outer[0], outer[1], outer[0]], [outer[0], outer[1]], [outer[0], PO::Coordinate.new(-70.9995, 43.0), outer[1]]].each do |points|
      expect_raises(PO::Invalid) { PO::Outline.new([PO::Ring.new("lawn", points)]) }
    end
  end

  it "refuses outside, touching, overlapping and nested exclusions" do
    outer = PO::Ring.new("lawn", rectangle)
    [rectangle(-71.1, 43.0), rectangle(-71.0, 43.0002, 0.0002), rectangle(-70.9992, 43.0002, 0.0003)].each do |hole|
      expect_raises(PO::Invalid) { PO::Outline.new([outer, PO::Ring.new("hole", hole)]) }
    end
    hole = PO::Ring.new("hole", rectangle(-70.9998, 43.0002, 0.0005))
    [rectangle(-70.9996, 43.0003, 0.0005), rectangle(-70.9997, 43.0003, 0.0001), rectangle(-70.9993, 43.0002, 0.0001)].each do |other|
      expect_raises(PO::Invalid) { PO::Outline.new([outer, hole, PO::Ring.new("other", other)]) }
    end
  end

  it "refuses nonfinite coordinates, poles, antimeridian crossings and oversized geometry" do
    [Float64::NAN, Float64::INFINITY, -Float64::INFINITY, 181.0].each do |lon|
      expect_raises(PO::Invalid) { PO::Outline.new([PO::Ring.new("lawn", [PO::Coordinate.new(lon, 43.0)] + rectangle[1..])]) }
    end
    expect_raises(PO::Invalid) { PO::Outline.new([PO::Ring.new("lawn", rectangle(-71.0, 86.0))]) }
    expect_raises(PO::Invalid) { PO::Outline.new([PO::Ring.new("lawn", rectangle(-71.0, 43.0, 0.1))]) }
    points = [PO::Coordinate.new(179.999, 43.0), PO::Coordinate.new(-179.999, 43.0), PO::Coordinate.new(-179.999, 43.001)]
    expect_raises(PO::Invalid, /antimeridian/) { PO::Outline.new([PO::Ring.new("lawn", points)]) }
  end

  it "bounds hole and vertex counts and refuses unstable duplicate IDs" do
    expect_raises(PO::Invalid) { PO::Outline.new([] of PO::Ring) }
    expect_raises(PO::Invalid) { PO::Outline.new(Array.new(18) { |i| PO::Ring.new("ring-#{i}", rectangle) }) }
    points = Array.new(513) { |i| PO::Coordinate.new(-71.0 + 0.001 * Math.cos(i * Math::PI * 2 / 513), 43.0 + 0.001 * Math.sin(i * Math::PI * 2 / 513)) }
    expect_raises(PO::Invalid) { PO::Outline.new([PO::Ring.new("lawn", points)]) }
    expect_raises(PO::Invalid, /unique/) { PO::Outline.new([PO::Ring.new("same", rectangle), PO::Ring.new("same", rectangle)]) }
    expect_raises(PO::Invalid) { PO::Outline.new([PO::Ring.new("bad id", rectangle)]) }
  end

  it "refuses oversized malformed payloads and nonclosed GeoJSON rings" do
    expect_raises(PO::Invalid) { PO.parse(" " * (PO::MAX_BYTES + 1)) }
    ["null", "{}", "[", "{\"schema\":true}"].each { |raw| expect_raises(PO::Invalid) { PO.parse(raw) } }
    json = JSON.parse(PO::Outline.new([PO::Ring.new("lawn", rectangle)]).to_json)
    json["geometry"]["coordinates"][0].as_a.pop
    expect_raises(PO::Invalid, /closed/) { PO.parse(json.to_json) }
    expect_raises(PO::Invalid, /deeply/) { PO.parse("[" * 13 + "]" * 13) }
  end
end
