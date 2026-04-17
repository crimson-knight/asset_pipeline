require "spec"
require "../../src/ui"

describe UI::NotificationRequest do
  it "generates an identifier when omitted" do
    request = UI::NotificationRequest.new("Build finished", "Your export is ready.")
    request.identifier.should start_with("ui-notification-")
  end

  it "keeps caller-provided metadata" do
    request = UI::NotificationRequest.new(
      "Backup complete",
      "Archive synced to iCloud.",
      identifier: "backup-complete",
      subtitle: "Nightly job",
      delay_seconds: 30.0,
      repeats: true,
      sound: false,
      badge: 3,
      thread_id: "sync-status"
    )

    request.identifier.should eq("backup-complete")
    request.subtitle.should eq("Nightly job")
    request.delay_seconds.should eq(30.0)
    request.repeats.should be_true
    request.sound.should be_false
    request.badge.should eq(3)
    request.thread_id.should eq("sync-status")
  end

  it "clamps non-positive delays to a visible minimum" do
    request = UI::NotificationRequest.new("Ping", "Body", delay_seconds: 0.0)
    request.effective_delay_seconds.should eq(0.25)
  end

  it "clamps repeating notifications to the platform minimum" do
    request = UI::NotificationRequest.new("Reminder", "Stand up", delay_seconds: 5.0, repeats: true)
    request.effective_delay_seconds.should eq(60.0)
  end
end
