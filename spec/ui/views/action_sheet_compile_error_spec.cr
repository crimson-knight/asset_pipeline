require "../../spec_helper"

# Concurrency-safe counter shared across compile-error specs in this
# process so parallel runs cannot collide on tempfile paths.
module Phase04CompileCheck
  @@counter = Atomic(Int32).new(0)

  def self.next_id : Int32
    @@counter.add(1)
  end

  PROJECT_ROOT = File.expand_path("../../..", __DIR__)
  TEMP_DIR     = File.join(PROJECT_ROOT, "tmp", "compile-check")

  def self.write_source(snippet : String) : String
    Dir.mkdir_p(TEMP_DIR) unless Dir.exists?(TEMP_DIR)
    path = File.join(TEMP_DIR,
      "asset-pipeline-compile-check-#{Process.pid}-#{next_id}.cr")
    File.write(path, snippet)
    path
  end

  def self.run(snippet : String, flags : Array(String) = [] of String) : {Process::Status, String}
    path = write_source(snippet)
    combined = IO::Memory.new
    begin
      status = Process.run(
        "crystal",
        ["build", "--no-codegen"] + flags + [path],
        output: combined,
        error: combined,
      )
      {status, combined.to_s}
    ensure
      File.delete(path) if File.exists?(path)
    end
  end
end

describe "UI::ActionSheet (compile-time gate)" do
  it "raises a useful compile error when used without -Dios" do
    snippet = <<-CR
      require "../../src/ui"
      sheet = UI::ActionSheet.new("Title", "Message")
    CR
    status, output = Phase04CompileCheck.run(snippet)
    status.success?.should be_false
    output.should contain("UI::ActionSheet is iOS-only")
    output.should contain("-Dios")
    output.should contain("UI::ActionSheetWithWebFallback")
    output.should contain("{% if flag?(:ios) %}")
  end

  it "compiles cleanly when built with -Dios" do
    snippet = <<-CR
      require "../../src/ui"
      sheet = UI::ActionSheet.new("Title", "Message")
    CR
    status, output = Phase04CompileCheck.run(snippet, flags: ["-Dios"])
    if !status.success?
      fail("Expected success with -Dios, got:\n#{output}")
    end
  end
end
