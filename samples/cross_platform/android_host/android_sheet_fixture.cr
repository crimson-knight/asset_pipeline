module AndroidSheetFixture
  @@sheet : UI::Sheet? = nil
  @@draft = "Draft 雪 😀"
  @@saved = "Nothing saved"
  @@dismissals = 0
  @@saves = 0
  @@behind = 0
  @@included = true
  @@follow_after_close = false
  @@followup : UI::Alert? = nil

  private def self.mark(view : UI::View, id : String)
    view.state_key = view.test_id = id
    view
  end

  def self.sheet : UI::Sheet
    @@sheet ||= UI::Sheet.new.tap do |value|
      mark(value, "sheet-editor")
      value.accessibility_label = "Native editor sheet"
      value.on_dismiss = -> {
        @@dismissals += 1
        followup.is_presented = true if @@follow_after_close
        @@follow_after_close = false
        nil
      }
    end
  end

  def self.followup : UI::Alert
    @@followup ||= UI::Alert.new("After the native sheet", "The sheet dismissed before this alert opened.").tap do |value|
      mark(value, "sheet-followup")
    end
  end

  private def self.open(selected : Symbol = :large, locked : Bool = false, detents : Array(Symbol)? = nil) : Nil
    @@included = true
    sheet.hidden = false
    sheet.state_key = "sheet-editor"
    followup.is_presented = false
    sheet.detents = detents || [:small, :medium, :large]
    sheet.selected_detent = selected
    sheet.interactive_dismiss_disabled = locked
    sheet.is_presented = true
  end

  def self.build : UI::View
    content = UI::VStack.new(12.0, UI::Alignment::Leading)
    content.state_key = "sheet-content"
    content.padding = UI::EdgeInsets.new(top: 20.0, trailing: 20.0, bottom: 20.0, leading: 20.0)
    content << mark(UI::Label.new("Edit a native draft"), "sheet-title")
    field = UI::TextField.new("Sheet draft", text: @@draft) { |value| @@draft = value; nil }
    field.fill_horizontal = true
    content << mark(field, "sheet-draft")
    content << mark(UI::Label.new("Saved: #{@@saved}"), "sheet-saved")
    content << mark(UI::Button.new("Save draft") { @@saved = @@draft; @@saves += 1; nil }, "sheet-save")
    content << mark(UI::Button.new("Done with sheet") { sheet.dismiss! }, "sheet-done")
    content << mark(UI::Button.new("Close through presenter") { UI::SheetPresenter.new(sheet).dismiss; nil }, "sheet-presenter-done")
    content << mark(UI::Button.new("Remove sheet declaration") { @@included = false; nil }, "sheet-remove")
    content << mark(UI::Button.new("Close and show alert") { @@follow_after_close = true; sheet.dismiss! }, "sheet-chain")
    sheet.content = content

    root = UI::VStack.new(12.0, UI::Alignment::Leading)
    root.state_key = "native-sheet-contract"
    root << mark(UI::Label.new("Native sheets"), "sheet-heading")
    root << mark(UI::Label.new("Dismissals: #{@@dismissals}; saves: #{@@saves}; behind: #{@@behind}"), "sheet-status")
    root << mark(UI::Label.new("Current detent: #{sheet.selected_detent}"), "sheet-detent")
    root << mark(UI::Button.new("Open sheet") { open }, "sheet-open")
    root << mark(UI::Button.new("Open medium sheet") { open(:medium) }, "sheet-open-medium")
    root << mark(UI::Button.new("Open locked sheet") { open(:large, true) }, "sheet-open-locked")
    root << mark(UI::Button.new("Open small-only sheet") { open(:small, detents: [:small]) }, "sheet-open-small-only")
    root << mark(UI::Button.new("Open medium-only sheet") { open(:medium, detents: [:medium]) }, "sheet-open-medium-only")
    root << mark(UI::Button.new("Open large-only sheet") { open(:large, detents: [:large]) }, "sheet-open-large-only")
    root << mark(UI::Button.new("Open small-medium sheet") { open(:small, detents: [:small, :medium]) }, "sheet-open-small-medium")
    root << mark(UI::Button.new("Open small-large sheet") { open(:small, detents: [:small, :large]) }, "sheet-open-small-large")
    root << mark(UI::Button.new("Open medium-large sheet") { open(:medium, detents: [:medium, :large]) }, "sheet-open-medium-large")
    root << mark(UI::Button.new("Open three-height small sheet") { open(:small) }, "sheet-open-three-small")
    root << mark(UI::Button.new("Open locked small-only sheet") { open(:small, true, [:small]) }, "sheet-open-locked-small")
    root << mark(UI::Button.new("Underlying sheet action") { @@behind += 1; nil }, "sheet-behind")
    root << mark(UI::Button.new("Close sheet from app") { sheet.dismiss! }, "sheet-close-outside")
    root << mark(UI::Button.new("Replace sheet identity") { sheet.state_key = "sheet-editor-replaced"; nil }, "sheet-rekey")
    root << mark(UI::Button.new("Reset sheet counters") {
      @@follow_after_close = false
      followup.is_presented = false
      sheet.dismiss!
      @@dismissals = @@saves = @@behind = 0
      nil
    }, "sheet-reset")
    root << sheet if @@included
    root << followup
    root
  end
end
