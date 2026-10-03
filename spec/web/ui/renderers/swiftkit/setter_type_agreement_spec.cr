# Type agreement between the Crystal setters and the SwiftKit override
# properties they write.
#
# Every `APSK*Overrides` setter is reached through `objc_msgSend` with a
# selector built from a Symbol, so neither compiler checks that the value
# Crystal sends matches the type Swift declares. A raw integer sent to an
# `NSNumber?` setter is retained as an object pointer and crashes the app
# (an accessibility action count of 1 faulted at address 0x1). This spec
# reads the three sources and fails when any pair disagrees:
#
#   1. each `Populator` `sender.set_*` call and each direct
#      `LibSwiftKitBridge.apsk_overrides_set_*` call in a renderer,
#   2. the Swift property the selector resolves to, and
#   3. the ObjC trampoline, which must pass the setter an object (`id`).

require "../../../spec_helper"

private ROOT = File.expand_path("../../../../..", __DIR__)

private OVERRIDES_DIR = File.join(ROOT, "swift/AssetPipelineSwiftKit/Sources/AssetPipelineSwiftKit/Overrides")

# Swift property types each Crystal sender method may write. Every scalar
# is boxed on the way across, so no scalar Swift type appears here.
private SWIFT_TYPES_FOR_SENDER_METHOD = {
  "set_color"        => ["APSKPlatformColor?"],
  "set_number"       => ["NSNumber?"],
  "set_bool"         => ["NSNumber?"],
  "set_int"          => ["NSNumber?"],
  "set_uint64"       => ["NSNumber?"],
  "set_string"       => ["String?"],
  "set_string_array" => ["[String]"],
  "set_int_array"    => ["[NSNumber]"],
  "set_uint64_array" => ["[NSNumber]"],
  "set_bool_array"   => ["[NSNumber]"],
}

# The same table for the C trampolines a renderer calls directly.
private SWIFT_TYPES_FOR_TRAMPOLINE = {
  "color"        => ["APSKPlatformColor?"],
  "number"       => ["NSNumber?"],
  "bool"         => ["NSNumber?"],
  "int_boxed"    => ["NSNumber?"],
  "uint64_boxed" => ["NSNumber?"],
  "string"       => ["String?"],
  "string_array" => ["[String]"],
  "int_array"    => ["[NSNumber]"],
  "uint64_array" => ["[NSNumber]"],
  "bool_array"   => ["[NSNumber]"],
  "object_ptr"   => ["AnyObject?"],
}

private record SetterCall, source : String, method : String, selector : String

# Maps each ObjC property name to every Swift type it is declared with
# across the override classes.
private def list_of_swift_property_types : Hash(String, Array(String))
  types_by_property = Hash(String, Array(String)).new { |hash, key| hash[key] = [] of String }
  Dir.glob(File.join(OVERRIDES_DIR, "*.swift")).each do |path|
    File.read(path).scan(/@objc(?:\((\w+)\))?\s+(?:public\s+|open\s+)*var\s+(\w+)\s*:\s*([^=\{\n]+)/) do |match|
      objc_name = match[1]? || match[2]
      types_by_property[objc_name] << match[3].strip
    end
  end
  types_by_property
end

private def property_name_for(selector : String) : String
  name = selector.rchop(':').lchop("set")
  name[0].downcase + name[1..]
end

private def list_of_populator_setter_calls : Array(SetterCall)
  source = File.join(ROOT, "src/ui/native/swiftkit_overrides.cr")
  File.read(source).scan(/sender\.(set_\w+)\(\s*\w+\s*,\s*:(\w+)/m).map do |match|
    SetterCall.new(source: "swiftkit_overrides.cr", method: match[1], selector: match[2])
  end
end

private def list_of_direct_trampoline_calls : Array(SetterCall)
  calls = [] of SetterCall
  Dir.glob(File.join(ROOT, "src/ui/renderers/*.cr")).each do |path|
    File.read(path).scan(/apsk_overrides_set_(\w+)\(\s*\w+\s*,\s*"(\w+):"/m) do |match|
      calls << SetterCall.new(source: File.basename(path), method: match[1], selector: match[2])
    end
  end
  calls
end

private def list_of_disagreements(calls : Array(SetterCall), table : Hash(String, Array(String))) : Array(String)
  swift_types = list_of_swift_property_types
  calls.compact_map do |call|
    allowed = table[call.method]?
    next "#{call.source}: #{call.method} has no entry in the type table" unless allowed
    property = property_name_for(call.selector)
    declared = swift_types[property]?
    next "#{call.source}: #{call.method}(:#{call.selector}) writes no declared Swift property" unless declared
    mismatched = declared.reject { |type| allowed.includes?(type) }
    next if mismatched.empty?
    "#{call.source}: #{call.method}(:#{call.selector}) sends #{allowed.join(" or ")} but `#{property}` is declared #{mismatched.join(", ")}"
  end
end

describe "SwiftKit setter type agreement" do
  it "finds the setters it audits" do
    list_of_swift_property_types.size.should be > 100
    list_of_populator_setter_calls.size.should be > 150
    list_of_direct_trampoline_calls.size.should be > 0
  end

  it "has every Populator setter send the type its Swift property declares" do
    list_of_disagreements(list_of_populator_setter_calls, SWIFT_TYPES_FOR_SENDER_METHOD).should eq([] of String)
  end

  it "has every direct renderer trampoline call send the type its Swift property declares" do
    list_of_disagreements(list_of_direct_trampoline_calls, SWIFT_TYPES_FOR_TRAMPOLINE).should eq([] of String)
  end

  it "has every overrides trampoline pass the setter an object, never a raw scalar" do
    bridge = File.read(File.join(ROOT, "src/ui/native/swiftkit_bridge.m"))
    trampolines = bridge.scan(/^void (apsk_overrides_set_\w+)\(.*?^\}/m)
    trampolines.size.should be > 10
    raw_scalar = trampolines.compact_map do |match|
      body = match[0]
      match[1] unless body.includes?("(void (*)(id, SEL, id))objc_msgSend")
    end
    raw_scalar.should eq([] of String)
  end

  it "declares every stored override property as an object type" do
    scalar = [] of String
    Dir.glob(File.join(OVERRIDES_DIR, "*Overrides.swift")).each do |path|
      File.read(path).scan(/@objc(?:\(\w+\))?\s+(?:public\s+|open\s+)*var\s+(\w+)\s*:\s*(Int|UInt64|Int64|Double|Float|CGFloat|Bool)\s*=/) do |match|
        scalar << "#{File.basename(path)}: #{match[1]} : #{match[2]}"
      end
    end
    scalar.should eq([] of String)
  end
end
