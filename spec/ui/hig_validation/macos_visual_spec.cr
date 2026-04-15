{% if flag?(:macos) %}
require "spec"
require "json"

# ---------------------------------------------------------------------------
# macOS visual-validation harness.
#
# For each entry in validation/worklist.json with role == "component":
#   1. Launch bin/hig_showcase as a subprocess with HIG_SLUG=<slug> and
#      HIG_SCREENSHOT_PATH=<out_path>.
#   2. The host (samples/cross_platform/macos_host/window_helper.m) snapshots
#      its own contentView via [NSView cacheDisplayInRect:toBitmapImageRep:]
#      0.6s after the run loop starts, writes the PNG, and exit(0)s.
#   3. We wait for the process to exit and verify the file.
#
# This path needs NEITHER Screen Recording (TCC) NOR Accessibility permission
# because the host snapshots its own views, not the framebuffer.
#
# Run:
#   HIG_ONLY=action-sheets crystal-alpha spec spec/ui/hig_validation/macos_visual_spec.cr -Dmacos \
#     --link-flags="-framework ApplicationServices -framework CoreFoundation"
# ---------------------------------------------------------------------------

SHARD_ROOT     = File.expand_path("../../..", __DIR__)
SHOWCASE_BIN   = File.join(SHARD_ROOT, "samples/cross_platform/macos_host/bin/hig_showcase")
WORKLIST_PATH  = File.join(SHARD_ROOT, ".claude/skills/apple-platform-guide/validation/worklist.json")
SCREENSHOT_DIR = File.join(SHARD_ROOT, ".claude/skills/apple-platform-guide/validation/screenshots")
BACKDROPS_DIR  = File.join(SHARD_ROOT, ".claude/skills/apple-platform-guide/validation/backdrops")

only_slug = ENV["HIG_ONLY"]?

raw      = File.read(WORKLIST_PATH)
worklist = JSON.parse(raw)
pages    = worklist["pages"].as_a

components = pages.select do |page|
  page["role"].as_s == "component" && (only_slug.nil? || page["slug"].as_s == only_slug)
end

# Each slug produces TWO captures: light and dark. The iteration-16
# acceptance bar requires both appearances validated independently.
APPEARANCES = ["light", "dark"]

# Resolve backdrop path for a slug + appearance from the worklist row.
# Returns nil if no backdrop field or the file does not exist.
def backdrop_path_for(page : JSON::Any, appearance : String) : String?
  stem = page["backdrop"]?.try(&.as_s?)
  return nil unless stem
  candidate = File.join(BACKDROPS_DIR, "#{stem}-#{appearance}.png")
  File.exists?(candidate) ? candidate : nil
end

describe "HIG macOS visual validation" do
  unless File.exists?(SHOWCASE_BIN)
    pending "bin/hig_showcase not built (run: make -C samples/cross_platform/macos_host build)"
    next
  end

  Dir.mkdir_p(SCREENSHOT_DIR)

  components.each do |page|
    slug = page["slug"].as_s

    APPEARANCES.each do |appearance|
      it "renders #{slug} (#{appearance})" do
        out_path = File.join(SCREENSHOT_DIR, "#{slug}-macos-#{appearance}.png")
        File.delete(out_path) if File.exists?(out_path)

        env = {
          "HIG_SLUG"            => slug,
          "HIG_SCREENSHOT_PATH" => out_path,
          "HIG_APPEARANCE"      => appearance,
        }

        # Auto-select backdrop from worklist `backdrop` field.
        # Phase 0.3 added this field; Phase 0.1 wired HIG_BACKDROP_PATH
        # into window_helper.m (objc_install_backdrop). The spec was the
        # missing link — it never forwarded the path. Wired here so every
        # slug with a backdrop entry gets the correct gradient/mock behind
        # its glass surface without any per-run manual env override.
        if (bp = backdrop_path_for(page, appearance))
          env = env.merge({"HIG_BACKDROP_PATH" => bp})
        end

        process = Process.new(
          SHOWCASE_BIN,
          env: env,
          output: Process::Redirect::Close,
          error: Process::Redirect::Close,
        )

        # 5s ceiling. Host should snapshot + exit at ~0.6s. If something hangs
        # we don't want the spec stuck forever. Poll Process.exists? rather than
        # blocking on .wait so we can enforce the deadline.
        deadline = Time.monotonic + 5.seconds
        pid = process.pid
        finished = false
        until Time.monotonic >= deadline
          unless Process.exists?(pid)
            finished = true
            break
          end
          sleep(0.1.seconds)
        end

        if finished
          status = process.wait
          status.success?.should be_true
        else
          process.terminate rescue nil
          process.wait rescue nil
          fail "host did not exit within 5s for slug=#{slug} appearance=#{appearance}"
        end

        File.exists?(out_path).should be_true
        File.size(out_path).should be > 1000
      end
    end
  end
end

{% end %}
