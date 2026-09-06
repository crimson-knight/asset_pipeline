module AndroidDialogFixture
  @@actions = 0
  @@cancellations = 0
  @@confirmations = 0
  @@underlying = 0
  @@alert : UI::Alert? = nil
  @@confirmation : UI::ConfirmationDialog? = nil
  @@default_alert : UI::Alert? = nil

  private def self.mark(view : UI::View, id : String)
    view.test_id = view.state_key = id
    view
  end

  def self.alert : UI::Alert
    @@alert ||= UI::Alert.new("Native alert 雪 😀", "This is a real Android modal window.").tap do |view|
      mark(view, "dialog-alert")
      view.add_button("Cancel", :cancel) { @@cancellations += 1; nil }
      view.add_button("Continue") { @@actions += 1; nil }
      view.add_button("Delete", :destructive) { @@actions += 10; nil }
    end
  end

  def self.confirmation : UI::ConfirmationDialog
    @@confirmation ||= UI::ConfirmationDialog.new("Delete this draft?", "Confirm or cancel the native action.").tap do |view|
      mark(view, "dialog-confirmation")
      view.confirm_label = "Delete draft"
      view.confirm_style = :destructive
      view.cancel_label = "Keep draft"
      view.on_confirm = -> { @@confirmations += 1; nil }
      view.on_cancel = -> { @@cancellations += 1; nil }
    end
  end

  def self.default_alert : UI::Alert
    @@default_alert ||= UI::Alert.new("Default native action", "An empty action list supplies a real dismissing OK button.").tap { |view| mark(view, "dialog-default") }
  end

  def self.close_all : Nil
    alert.is_presented = confirmation.is_presented = default_alert.is_presented = false
  end

  def self.build : UI::View
    root = UI::VStack.new(12.0, UI::Alignment::Leading)
    root.state_key = "native-dialog-contract"
    root << mark(UI::Label.new("Native dialogs"), "dialog-heading")
    root << mark(UI::Button.new("Underlying action") { @@underlying += 1; nil }, "dialog-underlying")
    root << mark(UI::Label.new("Actions: #{@@actions}; cancels: #{@@cancellations}; confirms: #{@@confirmations}; underlying: #{@@underlying}"), "dialog-status")
    root << mark(UI::Button.new("Open alert") { close_all; alert.is_presented = true; nil }, "dialog-open-alert")
    root << mark(UI::Button.new("Open confirmation") { close_all; confirmation.is_presented = true; nil }, "dialog-open-confirmation")
    root << mark(UI::Button.new("Open default alert") { close_all; default_alert.is_presented = true; nil }, "dialog-open-default")
    root << mark(UI::Button.new("Close programmatically") { close_all }, "dialog-close-all")
    root << mark(UI::Button.new("Reset counters") { close_all; @@actions = @@cancellations = @@confirmations = @@underlying = 0; nil }, "dialog-reset")
    root << alert
    root << confirmation
    root << default_alert
    root
  end
end
