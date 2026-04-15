# CrystalHIGHost iOS bridge.
#
# Cross-compiled via samples/cross_platform/ios_host/build_crystal_lib.sh into
# libhighost.a, linked into the Swift host app (CrystalHIGHost target).
#
# Exposes C-ABI functions callable from Swift through the bridging header.
#
# Pattern mirrors happy_coach/mobile/shared/bridge.cr -- guarded by
# {% if flag?(:ios) %} so the file also compiles for host tooling without
# pulling in UIKit renderer code.

{% if flag?(:ios) %}

require "../../../src/ui"
require "../../../src/ui/validation_scenes"

module CrystalHIGHost::Bridge
  @@initialized = false
  # Keep the NativeView tree alive so the NSObject retain counts don't
  # drop to zero after Swift takes the pointer. One slot per render is
  # enough for this validation host.
  @@last_native : UI::NativeView? = nil

  def self.initialize_runtime
    return if @@initialized
    GC.init
    @@initialized = true
  end

  def self.last_native=(nv : UI::NativeView)
    @@last_native = nv
  end

  # Map a slug to its scene name without using a Hash constant.
  # A Hash constant initialized at module level requires the Crystal runtime
  # (fiber/thread subsystem) to be running when first accessed. On iOS, the
  # first call to crystal_render_slug arrives from SwiftUI's layout pass
  # (UIViewRepresentable.makeUIView), which runs on the main UIKit thread
  # BEFORE Crystal's lazy-initialized Thread::current / once mechanism is
  # set up. Accessing a Hash constant in that context crashes with SIGSEGV
  # at 0x21 (null + 33). A case expression generates plain conditional
  # branches and is safe to call from any thread at any time.
  private def self.scene_for_slug(slug : String) : String?
    case slug
    when "sheets"        then "dashboard"
    when "alerts"        then "dashboard"
    when "popovers"      then "dashboard"
    when "action-sheets"   then "dashboard"
    when "activity-views"  then "dashboard"
    when "edit-menus"      then "document"
    when "context-menus" then "document"
    when "dock-menus"    then "dock"
    else                      nil
    end
  end

  # Wrap a focal component in the appropriate scene composer.
  # Returns the focal unwrapped if no scene is mapped for the slug.
  # The returned view has test_id "hig-component-root" so the iOS XCUITest
  # harness can confirm the app launched and rendered content.
  def self.wrap_in_scene(slug : String, focal : UI::View) : UI::View
    scene_view = case scene_for_slug(slug)
    when "dashboard"
      if slug == "sheets"
        # iOS sheet: return the glass directly so SwiftUI's UIViewRepresentable
        # proposes the full safe area to it. The HIGBackdropController gradient
        # (installed in the window at index 0) provides the dimmed backdrop.
        # Bypassing the DashboardScene avoids UIStackView distribution ambiguity
        # that was clipping the sheet at the Weight field (ios_sh_actions invisible).
        # The glass has minimum_height == maximum_height == 400pt so SwiftUI sizes
        # it correctly via systemLayoutSizeFitting.
        focal
      elsif slug == "action-sheets"
        # iOS action sheet: bottom-anchored layout per HIG.
        # HIG iOS: "On iPhone, action sheets always appear at the bottom of the screen."
        # Use :bottom_sheet focal position to place the glass at the bottom of a
        # compact single-column iOS backdrop (no sidebar, no 3-col chrome).
        UI::ValidationScenes::DashboardScene.new(focal: focal, focal_position: :bottom_sheet).build
      elsif slug == "activity-views"
        # iOS activity view (share sheet): appears as a bottom-anchored modal per HIG.
        # HIG: "An activity view can appear as a sheet or a popover, depending on the
        # device and orientation." On iPhone it is always a sheet from the bottom.
        # Use :bottom_sheet focal position — same compact single-column iOS backdrop
        # as action-sheets — so the glass card is visible in the capture viewport.
        # The 1200pt minimum_width of the 3-column :center_modal chrome overflows the
        # iPhone display and pushes the focal off-screen.
        UI::ValidationScenes::DashboardScene.new(focal: focal, focal_position: :bottom_sheet).build
      else
        # All other dashboard slugs (alerts, popovers) use :center_modal.
        UI::ValidationScenes::DashboardScene.new(focal: focal, focal_position: :center_modal).build
      end
    when "document"
      UI::ValidationScenes::DocumentScene.new(focal: focal, focal_position: :adjacent_to_selection).build
    when "dock"
      UI::ValidationScenes::DockScene.new(focal: focal, focal_position: :above_dock_icon).build
    else
      focal
    end
    # Tag the root view so the iOS XCUITest accessibility probe can find it.
    scene_view.accessibility_label = "hig-component-root"
    scene_view.test_id = "hig-component-root"
    scene_view
  end

  # Dispatch slug -> UI::View. Keep constructor arguments aligned with
  # src/ui/views/<name>.cr; unknown slugs render a Label placeholder so
  # the UITest still finds the accessibility root.
  def self.build_component(slug : String) : UI::View
    # Build the focal component first.
    focal = build_focal(slug)
    # If a scene is mapped for this slug, wrap it; otherwise return the plain focal.
    # Use scene_for_slug (a case expression) rather than a Hash constant lookup
    # to avoid the Crystal runtime crash documented in scene_for_slug above.
    if scene_for_slug(slug)
      wrap_in_scene(slug, focal)
    elsif isolation_plate_slug?(slug)
      centered_isolation_plate(focal)
    else
      focal
    end
  end

  private def self.isolation_plate_slug?(slug : String) : Bool
    case slug
    when "boxes", "collections", "progress-indicators", "text-fields"
      true
    else
      false
    end
  end

  private def self.centered_isolation_plate(focal : UI::View) : UI::View
    # Centering contract (measured iteration, root-cause recorded in
    # feedback_reflection_over_shotgun.md):
    #
    # SwiftUI's ContentView uses `.frame(maxWidth: .infinity, alignment: .center)`
    # on the UIViewRepresentable. UIStackView with alignment=Center does not
    # reliably center a pinned-width child when the parent's own width is
    # proposed by SwiftUI — the child either flush-lefts or stretches past
    # its required-priority width pin.
    #
    # Robust centering pattern: surround the focal with a pair of unpinned
    # Spacers inside an HStack (default Fill distribution). Two unpinned
    # Spacers in a horizontal UIStackView split the remaining space evenly.
    # The focal's own width pin survives because the Spacers absorb the
    # difference. Works on both macOS and iOS.
    h_center = UI::HStack.new(spacing: 0.0)
    h_center << UI::Spacer.new.as(UI::View)
    h_center << focal
    h_center << UI::Spacer.new.as(UI::View)

    plate = UI::VStack.new(spacing: 0.0)
    plate.minimum_height = 760.0
    plate << UI::Spacer.new.as(UI::View)
    plate << h_center.as(UI::View)
    plate << UI::Spacer.new.as(UI::View)
    plate.accessibility_label = "hig-component-root"
    plate.test_id = "hig-component-root"
    plate.as(UI::View)
  end

  # Build just the focal component (the raw view without scene chrome).
  # Split from build_component so tests can exercise the focal in isolation.
  # NOTE: The "HIG: <slug>" debug label was removed. Scene-label debug strings
  # must not appear in user-facing validation captures (Issue B). Slugs without
  # a scene wrapper (e.g. buttons, toggles, sidebars) were showing this label
  # as visible text in the rendered output.
  def self.build_focal(slug : String) : UI::View
    vstack = UI::VStack.new(spacing: 16.0)

    child = case slug
            when "alerts"
              # Amber alert: "Reshape today's timeline?" — destructive action
              # erases 3h of context. Amber copy per brand/amber.md.
              # HIG: "Use the destructive style to identify a button that performs
              # a destructive action people didn't deliberately choose." — Alerts.
              # Inline glass-card via UIVisualEffectView (UIGlassEffect iOS 26 /
              # UIBlurEffectStyleSystemMaterial fallback). Not via is_presented.
              ios_alert = UI::Alert.new("Reshape today's timeline?", "This will erase 3 hours of context. Amber cannot restore them.")
              ios_alert.add_button("Cancel", :cancel)
              ios_alert.add_button("Reshape", :destructive)
              ios_alert.as(UI::View)
            when "action-sheets"
              # HIG canonical action sheet layout (Mail cancel-draft pattern).
              # HIG iOS: "On iPhone, action sheets always appear at the bottom."
              # HIG: "Make destructive choices visually prominent; place them at
              # the top of the action sheet." HIG: "Place the Cancel button at
              # the bottom, separated from the other actions."
              # The Cancel button renders as a VISUALLY SEPARATE capsule with an
              # 8pt gap below the main action group — matching HIG canonical
              # Mail action-sheet illustration. Bottom-anchored via :bottom_sheet.
              # Corner radius 16pt (Amber phi-scale "sheet" token).

              # Main action card: prompt + 3 actions (destructive first, per HIG).
              main_content = UI::VStack.new(spacing: 8.0)
              main_prompt = UI::Label.new("What should Amber do with this draft?")
              main_prompt.font = UI::Font.new(size: 15.0, weight: :semibold)
              main_prompt.accessibility_label = "Action sheet prompt"
              main_content << main_prompt.as(UI::View)
              main_content << UI::Button.new("Banish draft forever", role: :destructive)
              main_content << UI::Button.new("Archive to vault")
              main_content << UI::Button.new("Conjure copy")
              main_sheet = UI::Sheet.new(main_content.as(UI::View), surface_style: :grouped_card)
              main_sheet.minimum_height = 220.0
              main_sheet.maximum_height = 220.0
              main_sheet.accessibility_label = "Action sheet: draft management"

              # Detached Cancel capsule — 8pt gap below main card per HIG.
              # HIG: "Provide a Cancel button. On iPhone, always add a Cancel
              # button so people can abandon the action."
              cancel_content = UI::VStack.new(spacing: 0.0)
              cancel_btn = UI::Button.new("Never mind", role: :cancel)
              cancel_content << cancel_btn.as(UI::View)
              cancel_sheet = UI::Sheet.new(cancel_content.as(UI::View), surface_style: :grouped_card)
              cancel_sheet.minimum_height = 60.0
              cancel_sheet.maximum_height = 60.0
              cancel_sheet.accessibility_label = "Cancel action sheet"

              # Gallery: main card + 8pt spacer + cancel capsule.
              # Total focal height: 220 + 8 + 60 = 288pt.
              gallery = UI::VStack.new(spacing: 8.0)
              gallery.alignment = UI::Alignment::Fill
              gallery << main_sheet.as(UI::View)
              gallery << cancel_sheet.as(UI::View)
              gallery.as(UI::View)
            when "activity-views"
              # UI::ActivityView — four-zone share sheet.
              # HIG: "An activity view presents sharing activities like messaging
              # and actions like Copy and Print, in addition to quick access to
              # frequently used apps." Rendered inline for capture path.
              # Production: dispatch UIActivityViewController instead.
              # minimum_height=320pt: header ~50pt + dest row ~80pt + action
              # grid ~110pt + cancel ~44pt + insets 36pt = ~320pt. Fixed height
              # so UIStackView distribution does not collapse the glass card in
              # the :bottom_sheet compact iOS scene. Amber content per brand/amber.md.
              act = UI::ActivityView.new(
                title: "Nature Walks",
                subtitle: "12 photos · 3.4 MB",
                thumbnail: UI::Image.new("photo"),
                destinations: [
                  UI::ActivityDestination.new(icon_symbol: "envelope",  label: "Mail"),
                  UI::ActivityDestination.new(icon_symbol: "message",   label: "Messages"),
                  UI::ActivityDestination.new(icon_symbol: "wifi",      label: "AirDrop"),
                  UI::ActivityDestination.new(icon_symbol: "note.text", label: "Notes"),
                  UI::ActivityDestination.new(icon_symbol: "archivebox", label: "Vault"),
                ],
                actions: [
                  UI::ActivityAction.new(icon_symbol: "folder",     label: "Save to Files"),
                  UI::ActivityAction.new(icon_symbol: "wand.and.stars", label: "Conjure copy"),
                  UI::ActivityAction.new(icon_symbol: "doc.on.doc", label: "Copy"),
                  UI::ActivityAction.new(icon_symbol: "printer",    label: "Print"),
                ],
                on_cancel: -> { }
              )
              # minimum_height=300pt prevents UIStackView from collapsing the
              # glass card. No maximum_height — the card auto-sizes to content
              # (all four HIG zones: header + dest row + action grid + cancel).
              act.minimum_height = 300.0
              act.accessibility_label = "Activity view: Nature Walks share sheet"
              act.as(UI::View)
            when "boxes"
              # HIG Box -> UI::Card -> UIView grouped container. iOS/iPadOS
              # HIG platform note: "iOS and iPadOS use the secondary and
              # tertiary background colors in boxes." Render title + body +
              # two label/value rows; keep buttons out so the verdict can
              # evaluate the card chrome itself (avoiding the UI::Button#role
              # gap documented in gaps.md).
              box_body = UI::VStack.new(spacing: 10.0)
              box_body.alignment = UI::Alignment::Leading
              box_intro = UI::Label.new("Your order ships in a reusable padded mailer.")
              box_intro.font = UI::Font.new(size: 15.0, weight: :regular)
              box_body << box_intro.as(UI::View)
              box_row1 = UI::HStack.new(spacing: 12.0)
              box_row1.alignment = UI::Alignment::Center
              box_carrier_label = UI::Label.new("Carrier")
              box_carrier_label.font = UI::Font.new(size: 13.0, weight: :semibold)
              box_carrier_label.text_color_role = UI::LabelRole::Secondary
              box_carrier_value = UI::Label.new("USPS Ground")
              box_carrier_value.font = UI::Font.new(size: 15.0, weight: :regular)
              box_row1 << box_carrier_label.as(UI::View)
              box_row1 << UI::Spacer.new.as(UI::View)
              box_row1 << box_carrier_value.as(UI::View)
              box_row2 = UI::HStack.new(spacing: 12.0)
              box_row2.alignment = UI::Alignment::Center
              box_arrival_label = UI::Label.new("Estimated arrival")
              box_arrival_label.font = UI::Font.new(size: 13.0, weight: :semibold)
              box_arrival_label.text_color_role = UI::LabelRole::Secondary
              box_arrival_value = UI::Label.new("Apr 17 - Apr 19")
              box_arrival_value.font = UI::Font.new(size: 15.0, weight: :regular)
              box_row2 << box_arrival_label.as(UI::View)
              box_row2 << UI::Spacer.new.as(UI::View)
              box_row2 << box_arrival_value.as(UI::View)
              box_body << box_row1
              box_body << box_row2
              box_card = UI::Card.new(box_body.as(UI::View))
              box_card.title = "Shipping details"
              box_card.content_padding = UI::EdgeInsets.new(top: 16.0, trailing: 18.0, bottom: 16.0, leading: 18.0)
              box_card.is_outlined = true
              box_card.minimum_width = 300.0
              box_card.maximum_width = 300.0
              box_card.as(UI::View)
            when "collections"
              # HIG Collections: "A collection manages an ordered set of
              # content and presents it in a customizable and highly visual
              # layout." HIG illustration shows a 4-column image grid.
              # We render a 3-column photo-tile grid using UI::ListView in
              # grid mode (layout: :grid, columns: 3) matching HIG best
              # practice: "Use the standard row or grid layout whenever
              # possible." Each tile is a VStack with a placeholder label
              # and a caption.
              make_tile = ->(symbol : String, caption : String) do
                tile = UI::VStack.new(spacing: 4.0)
                tile.alignment = UI::Alignment::Center
                tile.minimum_width = 96.0
                tile.maximum_width = 96.0
                tile.minimum_height = 96.0
                tile.padding = UI::EdgeInsets.new(top: 10.0, trailing: 8.0, bottom: 8.0, leading: 8.0)
                tile.corner_radius = 10.0
                tile.background = UI::Color.new(r: 0.96, g: 0.92, b: 0.86, a: 0.78)
                thumb = UI::Image.new(symbol)
                thumb.minimum_width = 34.0
                thumb.minimum_height = 34.0
                thumb.content_mode = UI::ContentMode::Fit
                thumb.tint_color = UI::Color.new(r: 0.36, g: 0.23, b: 0.58)
                cap = UI::Label.new(caption)
                cap.font = UI::Font.new(size: 12.0, weight: :regular)
                cap.text_color_role = nil
                cap.text_color = UI::Color.new(r: 0.45, g: 0.45, b: 0.45)
                tile << thumb.as(UI::View)
                tile << cap.as(UI::View)
                tile.as(UI::View)
              end
              coll_tiles = [
                make_tile.call("mountain.2", "Big Sur"),
                make_tile.call("sunrise", "Morning"),
                make_tile.call("figure.walk", "Trail"),
                make_tile.call("cup.and.saucer", "Coffee"),
                make_tile.call("sunset", "Sunset"),
                make_tile.call("water.waves", "Coast"),
                make_tile.call("leaf", "Forest"),
                make_tile.call("drop", "Lake"),
                make_tile.call("building.2", "City"),
              ]
              coll_stack = UI::VStack.new(spacing: 14.0)
              coll_stack.alignment = UI::Alignment::Leading
              coll_stack.minimum_width = 228.0
              coll_stack.maximum_width = 228.0
              coll_stack << UI::Label.new("Photos").tap { |l| l.font = UI::Font.new(size: 17.0, weight: :semibold) }.as(UI::View)
              coll_tiles.first(6).each_slice(2) do |pair|
                row = UI::HStack.new(spacing: 12.0)
                row.alignment = UI::Alignment::Center
                pair.each { |tile| row << tile }
                coll_stack << row.as(UI::View)
              end
              coll_stack.as(UI::View)
            when "lists-and-tables"
              # HIG "Lists and tables" gallery -- iter-31.
              # Three sections: plain list, inset-grouped card, accessory rows.
              # HIG Best practices: "Prefer displaying text in a list or table.
              # A table can include any type of content, but the row-based
              # format is especially well suited to making text easy to scan
              # and read." HIG iOS: "If you need to let people drill into a
              # list or table row's subviews, use a disclosure indicator
              # accessory control." We use U+276F as a disclosure-indicator
              # stand-in (UITableViewCell.AccessoryType.disclosureIndicator
              # requires a real UITableView, not a UIStackView row).
              ios_lt_row = ->(title : String, trailing : String) do
                r = UI::HStack.new(spacing: 12.0)
                r << UI::Label.new(title)
                r << UI::Spacer.new
                tl = UI::Label.new(trailing)
                tl.text_color = UI::Color.new(r: 0.55, g: 0.55, b: 0.55)
                r << tl.as(UI::View)
                r.as(UI::View)
              end

              ios_gallery = UI::VStack.new(spacing: 16.0)

              # Section 1: Plain list with hairline separators.
              ios_gallery << UI::Label.new("Plain List").as(UI::View)
              plain_items = [
                ios_lt_row.call("Mail", ""),
                ios_lt_row.call("Messages", ""),
                ios_lt_row.call("Notes", ""),
                ios_lt_row.call("Reminders", ""),
              ] of UI::View
              plain_sec = UI::ListView::Section.new(items: plain_items)
              plain_lst = UI::ListView.new(sections: [plain_sec], style: UI::ListStyle::Plain)
              plain_lst.shows_separators = true
              ios_gallery << plain_lst.as(UI::View)

              ios_gallery << UI::Divider.new(:horizontal).as(UI::View)

              # Section 2: Inset-grouped (rounded card).
              ios_gallery << UI::Label.new("Inset-Grouped List").as(UI::View)
              grouped_items = [
                ios_lt_row.call("General", "\u276F"),
                ios_lt_row.call("Appearance", "\u276F"),
                ios_lt_row.call("Sounds & Haptics", "\u276F"),
              ] of UI::View
              grouped_sec = UI::ListView::Section.new(header: "Settings", items: grouped_items)
              grouped_lst = UI::ListView.new(sections: [grouped_sec], style: UI::ListStyle::InsetGrouped)
              grouped_lst.shows_separators = true
              ios_gallery << grouped_lst.as(UI::View)

              ios_gallery << UI::Divider.new(:horizontal).as(UI::View)

              # Section 3: Accessory rows (chevron + value text).
              ios_gallery << UI::Label.new("Row Accessories").as(UI::View)
              acc_items = [
                ios_lt_row.call("Wi-Fi", "HomeNet \u276F"),
                ios_lt_row.call("Bluetooth", "On"),
                ios_lt_row.call("Cellular", "\u276F"),
              ] of UI::View
              acc_sec = UI::ListView::Section.new(items: acc_items)
              acc_lst = UI::ListView.new(sections: [acc_sec], style: UI::ListStyle::Grouped)
              acc_lst.shows_separators = true
              ios_gallery << acc_lst.as(UI::View)

              ios_gallery.as(UI::View)
            when "context-menus"
              # HIG context menu content: task-specific commands revealed by
              # long-press on iOS / iPadOS. HIG: "A context menu provides
              # access to functionality that's directly related to an item,
              # without cluttering the interface." Rendered inline as a
              # VStack of the menu's items (NOT a dismissed MenuButton
              # trigger) -- same pattern as alerts/action-sheets. Three
              # groups separated by Dividers per HIG: "use separators to
              # group items in a context menu and help people scan the menu
              # more quickly." Delete is last per iOS destructive-item
              # guidance: "list them at the end of the menu and identify
              # them as destructive."
              menu_content = UI::VStack.new(spacing: 4.0)
              menu_content << UI::Button.new("Cut", symbol: "scissors")
              menu_content << UI::Button.new("Copy", symbol: "doc.on.doc")
              menu_content << UI::Button.new("Paste", symbol: "clipboard")
              menu_content << UI::Divider.new(:horizontal)
              menu_content << UI::Button.new("Share...", symbol: "square.and.arrow.up")
              menu_content << UI::Button.new("Duplicate", symbol: "square.on.square")
              menu_content << UI::Divider.new(:horizontal)
              menu_content << UI::Button.new("Delete", role: :destructive, symbol: "trash")
              UI::Sheet.new(menu_content.as(UI::View), surface_style: :grouped_card).as(UI::View)
            when "digit-entry-views"
              # HIG digit entry view: full-screen PIN / passcode entry.
              # HIG abstract: "A digit entry view fills the entire screen
              # and prompts people to enter a series of digits, like a PIN,
              # using a digit-specific keyboard." HIG Platform considerations:
              # "Not supported in iOS, iPadOS, macOS, visionOS, or watchOS"
              # -- this component is tvOS-only (TVDigitEntryViewController).
              # We render a HIG-faithful *visual mock* using UI::TextField
              # primitives: title, prompt, and a horizontal row of 6 secure
              # TextField cells with NumberPad keyboard hints. Exercises the
              # HIG "line of digits" visual and secure-entry recommendation.
              digit_content = UI::VStack.new(spacing: 12.0)
              digit_content << UI::Label.new("Enter Passcode")
              digit_content << UI::Label.new("Enter the 6-digit code sent to your device.")
              digit_row = UI::HStack.new(spacing: 8.0)
              6.times do
                cell = UI::TextField.new("·")
                cell.secure_entry = true
                cell.keyboard_type = UI::KeyboardType::NumberPad
                digit_row << cell
              end
              digit_content << digit_row.as(UI::View)
              digit_content.as(UI::View)
            when "disclosure-controls"
              # HIG "Disclosure controls" (iOS/iPadOS): SwiftUI
              # DisclosureGroup view, rendered as a chevron-prefixed
              # UIButton row (chevron.right collapsed, chevron.down
              # expanded) + optional child UIStackView content.
              # HIG: "Disclosure controls are available in iOS, iPadOS,
              # and visionOS with the SwiftUI DisclosureGroup view."
              # Both expanded and collapsed states shown inline.
              disc_content = UI::VStack.new(spacing: 12.0)

              # Expanded group: General (chevron.down)
              ios_expanded = UI::DisclosureGroup.new("General", expanded: true)
              ios_expanded.content << UI::Label.new("Appearance: Auto")
              ios_expanded.content << UI::Label.new("Language & Region: English (US)")
              ios_expanded.content << UI::Label.new("Date & Time: Automatic")
              disc_content << ios_expanded.as(UI::View)

              # Collapsed group: Privacy & Security (chevron.right)
              ios_collapsed = UI::DisclosureGroup.new("Privacy & Security", expanded: false)
              ios_collapsed.content << UI::Label.new("Location Services: On")
              disc_content << ios_collapsed.as(UI::View)

              # Collapsed group: Notifications
              ios_notif = UI::DisclosureGroup.new("Notifications", expanded: false)
              ios_notif.content << UI::Label.new("Allow Notifications: On")
              disc_content << ios_notif.as(UI::View)

              disc_content << UI::Divider.new(:horizontal)

              # "Show More" disclosure button pattern (collapsed)
              ios_more = UI::DisclosureGroup.new("Show More", expanded: false)
              ios_more.content << UI::Label.new("Output: /Documents")
              disc_content << ios_more.as(UI::View)

              # "Show Less" disclosure button pattern (expanded)
              ios_less = UI::DisclosureGroup.new("Show Less", expanded: true)
              ios_less.content << UI::Label.new("Output: /Documents")
              ios_less.content << UI::Label.new("Format: PDF")
              ios_less.content << UI::Label.new("Color: sRGB")
              disc_content << ios_less.as(UI::View)

              disc_content.as(UI::View)
            when "dock-menus"
              # HIG Dock menus are macOS-only. Platform considerations:
              # "Not supported in iOS, iPadOS, tvOS, visionOS, or watchOS."
              # HIG note: "Although iOS and iPadOS don't support a Dock
              # menu, people can reveal a similar menu of system-provided
              # and custom items -- called Home Screen quick actions --
              # when they long press an app icon on the Home Screen or in
              # the Dock." That's tracked as the `home-screen-quick-actions`
              # slug (P2). For this validation we render a clearly-intentional
              # "macOS-only feature" placeholder card so the screenshot is
              # non-black and the platform exclusion is documented in-frame.
              # The surface uses UI::Sheet grouped_card so it reads as a
              # deliberate HIG-styled card rather than a blank fallback.
              dock_na_content = UI::VStack.new(spacing: 12.0)

              na_title = UI::Label.new("Dock Menus — macOS Only")
              na_title.font = UI::Font.new(size: 17.0, weight: :semibold)
              dock_na_content << na_title.as(UI::View)

              na_body = UI::Label.new("Dock menus are a macOS-exclusive feature. People secondary-click an app icon in the Dock to reveal custom and system items.")
              na_body.font = UI::Font.new(size: 15.0, weight: :regular)
              na_body.number_of_lines = 0
              dock_na_content << na_body.as(UI::View)

              dock_na_content << UI::Divider.new(:horizontal)

              na_alt_title = UI::Label.new("iOS equivalent")
              na_alt_title.font = UI::Font.new(size: 13.0, weight: :semibold)
              na_alt_title.text_color = UI::Color.new(r: 0.55, g: 0.55, b: 0.55)
              dock_na_content << na_alt_title.as(UI::View)

              na_alt_body = UI::Label.new("Home Screen quick actions (long-press on app icon) provide a similar contextual-command surface on iOS. See HIG: Home Screen quick actions.")
              na_alt_body.font = UI::Font.new(size: 13.0, weight: :regular)
              na_alt_body.number_of_lines = 0
              na_alt_body.text_color = UI::Color.new(r: 0.55, g: 0.55, b: 0.55)
              dock_na_content << na_alt_body.as(UI::View)

              UI::Sheet.new(dock_na_content.as(UI::View), surface_style: :grouped_card).as(UI::View)
            when "edit-menus"
              # HIG edit menu: the contextual text-editing surface revealed by
              # touch-and-hold / double-tap on a text selection (iOS / iPadOS).
              # HIG abstract: "An edit menu lets people make changes to
              # selected content in the current view, in addition to offering
              # related commands like Copy, Select, Translate, and Look Up."
              # HIG iOS behavior: "the edit menu displays commands in a
              # compact, horizontal list ... People can tap a chevron on the
              # trailing edge to expand it into a context menu." We mirror the
              # inline-VStack-in-Sheet pattern (not the compact horizontal bar)
              # so the screenshot captures the full vertical command set.
              # Canonical iOS UIResponderStandardEditActions item set:
              #   Group 1 (clipboard): Cut (scissors) / Copy (doc.on.doc)
              #                        / Paste (doc.on.clipboard)
              #   Separator
              #   Group 2 (selection): Select All (selection.pin.in.out)
              #   Separator
              #   Group 3 (find / utilities): Find... (magnifyingglass)
              #                               / Look Up (book)
              #                               / Translate (character.bubble)
              #   Separator
              #   Group 4 (share): Share (square.and.arrow.up)
              # No keyboard shortcut labels on iOS (touch platform). No
              # destructive items -- standard edit menu actions are clipboard
              # operations, not data-destroying. HIG "Best practices":
              # "Prefer the system-provided edit menu... For a list of
              # standard edit menu commands, see UIResponderStandardEditActions."
              edit_content = UI::VStack.new(spacing: 4.0)

              # --- Group 1: Clipboard ---
              edit_content << UI::Button.new("Cut", symbol: "scissors")
              edit_content << UI::Button.new("Copy", symbol: "doc.on.doc")
              edit_content << UI::Button.new("Paste", symbol: "doc.on.clipboard")

              edit_content << UI::Divider.new(:horizontal)

              # --- Group 2: Selection ---
              edit_content << UI::Button.new("Select All", symbol: "selection.pin.in.out")

              edit_content << UI::Divider.new(:horizontal)

              # --- Group 3: Find / utilities ---
              edit_content << UI::Button.new("Find\u2026", symbol: "magnifyingglass")
              edit_content << UI::Button.new("Look Up", symbol: "book")
              edit_content << UI::Button.new("Translate", symbol: "character.bubble")

              edit_content << UI::Divider.new(:horizontal)

              # --- Group 4: Share ---
              edit_content << UI::Button.new("Share", symbol: "square.and.arrow.up")

              UI::Sheet.new(edit_content.as(UI::View), surface_style: :grouped_card).as(UI::View)
            when "menus"
              # HIG menus content surface: the general menu surface shape
              # covering pull-down and pop-up menus on iOS / iPadOS. HIG
              # abstract: "A menu reveals its options when people interact
              # with it, making it a space-efficient way to present commands."
              # iOS-specific: "In iOS and iPadOS, a menu can display items
              # in small / medium / large layouts." No keyboard shortcut
              # labels on touch platforms (correct per HIG).
              #
              # Two inline menu surfaces:
              # Surface A: File pull-down (no Cmd shortcuts on iOS).
              # Surface B: Sort By pop-up with checkmark on Date.
              # Same inline-VStack-in-Sheet pattern as edit-menus / context-menus.
              ios_menus_outer = UI::VStack.new(spacing: 16.0)

              # --- Surface A: File pull-down (iOS) ---
              ios_file_content = UI::VStack.new(spacing: 4.0)

              ios_file_hdr = UI::Label.new("File Menu (pull-down)")
              ios_file_hdr.font = UI::Font.new(size: 11.0, weight: :semibold)
              ios_file_hdr.text_color = UI::Color.new(r: 0.55, g: 0.55, b: 0.55)
              ios_file_content << ios_file_hdr.as(UI::View)

              # Group 1: New / Open / Close (no shortcuts on iOS)
              ios_file_content << UI::Button.new("New", symbol: "doc")
              ios_file_content << UI::Button.new("Open\u2026", symbol: "folder.open")
              ios_file_content << UI::Button.new("Close", symbol: "xmark")

              ios_file_content << UI::Divider.new(:horizontal)

              # Group 2: Save / Revert
              ios_file_content << UI::Button.new("Save", symbol: "arrow.down.doc")
              ios_file_content << UI::Button.new("Revert", symbol: "arrow.counterclockwise")

              ios_file_content << UI::Divider.new(:horizontal)

              # Group 3: Export (submenu indicator via chevron) / Print
              ios_export_row = UI::HStack.new(spacing: 8.0)
              ios_export_row << UI::Button.new("Export", symbol: "square.and.arrow.up")
              ios_export_row << UI::Spacer.new
              ios_chevron = UI::Label.new("\u203a")
              ios_chevron.font = UI::Font.new(size: 15.0, weight: :regular)
              ios_chevron.text_color = UI::Color.new(r: 0.55, g: 0.55, b: 0.55)
              ios_export_row << ios_chevron.as(UI::View)
              ios_file_content << ios_export_row.as(UI::View)

              ios_file_content << UI::Button.new("Print\u2026", symbol: "printer")

              ios_file_surface = UI::Sheet.new(ios_file_content.as(UI::View), surface_style: :grouped_card)
              ios_menus_outer << ios_file_surface.as(UI::View)

              # --- Surface B: Sort By pop-up with checkmark ---
              ios_sort_content = UI::VStack.new(spacing: 4.0)

              ios_sort_hdr = UI::Label.new("Sort By (pop-up, selected: Date)")
              ios_sort_hdr.font = UI::Font.new(size: 11.0, weight: :semibold)
              ios_sort_hdr.text_color = UI::Color.new(r: 0.55, g: 0.55, b: 0.55)
              ios_sort_content << ios_sort_hdr.as(UI::View)

              ios_name_row = UI::HStack.new(spacing: 8.0)
              ios_name_spacer = UI::Label.new("  ")
              ios_name_spacer.font = UI::Font.new(size: 13.0, weight: :regular)
              ios_name_row << ios_name_spacer.as(UI::View)
              ios_name_row << UI::Button.new("Name", symbol: "character")
              ios_sort_content << ios_name_row.as(UI::View)

              ios_date_row = UI::HStack.new(spacing: 8.0)
              ios_checkmark = UI::Label.new("\u2713")
              ios_checkmark.font = UI::Font.new(size: 13.0, weight: :semibold)
              ios_date_row << ios_checkmark.as(UI::View)
              ios_date_row << UI::Button.new("Date", symbol: "calendar")
              ios_sort_content << ios_date_row.as(UI::View)

              ios_size_row = UI::HStack.new(spacing: 8.0)
              ios_size_spacer = UI::Label.new("  ")
              ios_size_spacer.font = UI::Font.new(size: 13.0, weight: :regular)
              ios_size_row << ios_size_spacer.as(UI::View)
              ios_size_row << UI::Button.new("Size", symbol: "arrow.up.arrow.down")
              ios_sort_content << ios_size_row.as(UI::View)

              ios_sort_surface = UI::Sheet.new(ios_sort_content.as(UI::View), surface_style: :grouped_card)
              ios_menus_outer << ios_sort_surface.as(UI::View)

              ios_menus_outer.as(UI::View)
            when "buttons"
              # HIG button gallery matching the macOS hig_showcase arm.
              # Eleven-row set covering all ButtonStyle variants, roles, and states.
              # UIButton.Configuration variants (iOS 15+):
              #   Default / Bordered -> .gray()    — bordered, gray fill
              #   Prominent          -> .filled()   — filled blue (or red for dest)
              #   Tinted             -> .tinted()   — translucent accent fill
              #   Borderless         -> .plain()    — text-link, no bezel
              ios_btn_gallery = UI::VStack.new(spacing: 10.0)
              ios_btn_gallery << UI::Label.new("Button Style / Role Gallery").tap { |l|
                l.font = UI::Font.new(size: 13.0, weight: :semibold)
              }
              # Row 1 -- Default (gray configuration, system bordered)
              ios_r1 = UI::HStack.new(spacing: 12.0)
              ios_r1 << UI::Label.new("Default")
              ios_r1 << UI::Button.new("Continue", style: UI::ButtonStyle::Default)
              ios_btn_gallery << ios_r1.as(UI::View)
              # Row 2 -- Prominent (filled blue CTA)
              ios_r2 = UI::HStack.new(spacing: 12.0)
              ios_r2 << UI::Label.new("Prominent")
              ios_r2 << UI::Button.new("Save", style: UI::ButtonStyle::Prominent)
              ios_btn_gallery << ios_r2.as(UI::View)
              # Row 3 -- Tinted (translucent accent fill)
              ios_r3 = UI::HStack.new(spacing: 12.0)
              ios_r3 << UI::Label.new("Tinted")
              ios_r3 << UI::Button.new("Add to List", style: UI::ButtonStyle::Tinted)
              ios_btn_gallery << ios_r3.as(UI::View)
              # Row 4 -- Bordered (same as Default, explicit knob)
              ios_r4 = UI::HStack.new(spacing: 12.0)
              ios_r4 << UI::Label.new("Bordered")
              ios_r4 << UI::Button.new("Options", style: UI::ButtonStyle::Bordered)
              ios_btn_gallery << ios_r4.as(UI::View)
              # Row 5 -- Borderless (plain configuration, text-link)
              ios_r5 = UI::HStack.new(spacing: 12.0)
              ios_r5 << UI::Label.new("Borderless")
              ios_r5 << UI::Button.new("Learn more", style: UI::ButtonStyle::Borderless)
              ios_btn_gallery << ios_r5.as(UI::View)
              # Row 6 -- Destructive role (red label on gray bezel)
              ios_r6 = UI::HStack.new(spacing: 12.0)
              ios_r6 << UI::Label.new("Destructive")
              ios_r6 << UI::Button.new("Delete", role: :destructive)
              ios_btn_gallery << ios_r6.as(UI::View)
              # Row 7 -- Cancel role (semibold per HIG)
              ios_r7 = UI::HStack.new(spacing: 12.0)
              ios_r7 << UI::Label.new("Cancel")
              ios_r7 << UI::Button.new("Cancel", role: :cancel)
              ios_btn_gallery << ios_r7.as(UI::View)
              # Row 8 -- Prominent + Destructive (red filled bezel)
              ios_r8 = UI::HStack.new(spacing: 12.0)
              ios_r8 << UI::Label.new("Prom + Dest")
              ios_r8 << UI::Button.new("Delete Account", role: :destructive, style: UI::ButtonStyle::Prominent)
              ios_btn_gallery << ios_r8.as(UI::View)
              # Row 9 -- Disabled
              ios_r9 = UI::HStack.new(spacing: 12.0)
              ios_r9 << UI::Label.new("Disabled")
              ios_dis = UI::Button.new("Unavailable")
              ios_dis.disabled = true
              ios_r9 << ios_dis.as(UI::View)
              ios_btn_gallery << ios_r9.as(UI::View)
              # Row 10 -- SF Symbol (share icon)
              ios_r10 = UI::HStack.new(spacing: 12.0)
              ios_r10 << UI::Label.new("SF Symbol")
              ios_r10 << UI::Button.new("Share", symbol: "square.and.arrow.up")
              ios_btn_gallery << ios_r10.as(UI::View)
              # Row 11 -- Destructive with symbol
              ios_r11 = UI::HStack.new(spacing: 12.0)
              ios_r11 << UI::Label.new("Dest + Symbol")
              ios_r11 << UI::Button.new("Remove", role: :destructive, symbol: "trash")
              ios_btn_gallery << ios_r11.as(UI::View)
              ios_btn_gallery.as(UI::View)
            when "toggles"
              # HIG toggles: six HIG-canonical scenarios covering ON, OFF,
              # Disabled-ON, Disabled-OFF states per Best practices.
              # HIG Best practices: "Make sure the visual differences in a
              # toggle's state are obvious." -- on (Amber gold), gray (off),
              # dimmed (disabled).
              # iOS: UISwitch -- setOn:animated: / setOnTintColor: / setEnabled:.
              # HIG iOS: "Use the switch toggle style only in a list row."
              # HIG iOS: "Use the same color for all switches in your app" --
              # all ON-state switches use Amber gold.
              # Dark mode fix (June R3): UISwitch.overrideUserInterfaceStyle is
              # set directly in the renderer from TEST_RUNNER_HIG_APPEARANCE so
              # the OFF-state track resolves as dark gray (#3A2A10 equivalent),
              # not cream (light mode fallback).
              ios_amber_gold_tgl = UI::Color.new(r: 1.0, g: 0.678, b: 0.2)
              ios_tgl_stack = UI::VStack.new(spacing: 16.0)

              # Row 1: ON state -- Amber gold track, thumb right
              ios_row1 = UI::HStack.new(spacing: 12.0)
              ios_lbl1 = UI::Label.new("Notifications")
              ios_lbl1.accessibility_label = "Notifications label"
              ios_row1 << ios_lbl1.as(UI::View)
              ios_row1 << UI::Spacer.new.as(UI::View)
              ios_tgl_on = UI::Toggle.new("", true)
              ios_tgl_on.tint_color = ios_amber_gold_tgl
              ios_tgl_on.accessibility_label = "Notifications toggle, on"
              ios_row1 << ios_tgl_on.as(UI::View)
              ios_tgl_stack << ios_row1.as(UI::View)

              # Row 2: OFF state -- system gray track (dark: dark gray pill),
              # thumb left. overrideUserInterfaceStyle is set per-switch in renderer.
              ios_row2 = UI::HStack.new(spacing: 12.0)
              ios_lbl2 = UI::Label.new("Dark Mode")
              ios_lbl2.accessibility_label = "Dark Mode label"
              ios_row2 << ios_lbl2.as(UI::View)
              ios_row2 << UI::Spacer.new.as(UI::View)
              ios_tgl_off = UI::Toggle.new("", false)
              ios_tgl_off.accessibility_label = "Dark Mode toggle, off"
              ios_row2 << ios_tgl_off.as(UI::View)
              ios_tgl_stack << ios_row2.as(UI::View)

              # Row 3: Disabled (OFF) -- dimmed, non-interactive.
              # HIG: "Clearly identify the setting, view, or content the toggle affects."
              ios_row3 = UI::HStack.new(spacing: 12.0)
              ios_lbl3 = UI::Label.new("Location")
              ios_lbl3.accessibility_label = "Location label"
              ios_row3 << ios_lbl3.as(UI::View)
              ios_row3 << UI::Spacer.new.as(UI::View)
              ios_tgl_disabled_off = UI::Toggle.new("", false)
              ios_tgl_disabled_off.disabled = true
              ios_tgl_disabled_off.accessibility_label = "Location toggle, disabled off"
              ios_row3 << ios_tgl_disabled_off.as(UI::View)
              ios_tgl_stack << ios_row3.as(UI::View)

              # Row 4: ON with Amber gold -- consistent brand accent per HIG.
              # "Use the same color for all switches in your app." Focus Mode
              # demonstrates ON state with the brand accent (Amber gold).
              ios_row4 = UI::HStack.new(spacing: 12.0)
              ios_lbl4 = UI::Label.new("Focus Mode")
              ios_lbl4.accessibility_label = "Focus Mode label"
              ios_row4 << ios_lbl4.as(UI::View)
              ios_row4 << UI::Spacer.new.as(UI::View)
              ios_tgl_focus = UI::Toggle.new("", true)
              ios_tgl_focus.tint_color = ios_amber_gold_tgl
              ios_tgl_focus.accessibility_label = "Focus Mode toggle, on"
              ios_row4 << ios_tgl_focus.as(UI::View)
              ios_tgl_stack << ios_row4.as(UI::View)

              # Row 5: Disabled ON -- gold track dimmed, non-interactive.
              # Stresses dark rendering: gold fill should remain visible at reduced alpha.
              ios_row5 = UI::HStack.new(spacing: 12.0)
              ios_lbl5 = UI::Label.new("Night Shift")
              ios_lbl5.accessibility_label = "Night Shift label"
              ios_row5 << ios_lbl5.as(UI::View)
              ios_row5 << UI::Spacer.new.as(UI::View)
              ios_tgl_disabled_on = UI::Toggle.new("", true)
              ios_tgl_disabled_on.tint_color = ios_amber_gold_tgl
              ios_tgl_disabled_on.disabled = true
              ios_tgl_disabled_on.accessibility_label = "Night Shift toggle, disabled on"
              ios_row5 << ios_tgl_disabled_on.as(UI::View)
              ios_tgl_stack << ios_row5.as(UI::View)

              # Row 6: Disabled OFF -- dark gray track dimmed.
              ios_row6 = UI::HStack.new(spacing: 12.0)
              ios_lbl6 = UI::Label.new("Auto Lock")
              ios_lbl6.accessibility_label = "Auto Lock label"
              ios_row6 << ios_lbl6.as(UI::View)
              ios_row6 << UI::Spacer.new.as(UI::View)
              ios_tgl_disabled_off2 = UI::Toggle.new("", false)
              ios_tgl_disabled_off2.disabled = true
              ios_tgl_disabled_off2.accessibility_label = "Auto Lock toggle, disabled off"
              ios_row6 << ios_tgl_disabled_off2.as(UI::View)
              ios_tgl_stack << ios_row6.as(UI::View)

              ios_tgl_stack.as(UI::View)
            when "text-fields"
              # HIG text-fields: four labelled variants on iOS UITextField.
              # UITextField with UITextBorderStyleRoundedRect for bordered chrome.
              # HIG Best practices: "Show a hint in a text field to help communicate
              # its purpose." -- placeholder for empty, filled value where appropriate.
              # iOS: "Display a Clear button in the trailing end."

              ios_tf_stack = UI::VStack.new(spacing: 14.0)
              ios_tf_stack.alignment = UI::Alignment::Leading
              ios_tf_stack.minimum_width = 320.0
              ios_tf_stack.maximum_width = 320.0
              ios_tf_stack.padding = UI::EdgeInsets.new(top: 18.0, trailing: 20.0, bottom: 18.0, leading: 20.0)
              ios_tf_stack << UI::Label.new("Account details").tap { |l| l.font = UI::Font.new(size: 17.0, weight: :semibold) }

              # Row 1: Name (empty, placeholder)
              ios_row1 = UI::VStack.new(spacing: 4.0)
              ios_row1.alignment = UI::Alignment::Leading
              ios_lbl1 = UI::Label.new("Name:")
              ios_lbl1.font = UI::Font.new(size: 13.0, weight: :regular)
              ios_lbl1.accessibility_label = "Name label"
              ios_tf1 = UI::TextField.new("Your name")
              ios_tf1.minimum_width = 260.0
              ios_tf1.accessibility_label = "Name field"
              ios_row1 << ios_lbl1.as(UI::View)
              ios_row1 << ios_tf1.as(UI::View)
              ios_tf_stack << ios_row1.as(UI::View)

              # Row 2: Email (filled)
              ios_row2 = UI::VStack.new(spacing: 4.0)
              ios_row2.alignment = UI::Alignment::Leading
              ios_lbl2 = UI::Label.new("Email:")
              ios_lbl2.font = UI::Font.new(size: 13.0, weight: :regular)
              ios_lbl2.accessibility_label = "Email label"
              ios_tf2 = UI::TextField.new("Email address")
              ios_tf2.text = "alice@example.com"
              ios_tf2.minimum_width = 260.0
              ios_tf2.keyboard_type = UI::KeyboardType::EmailAddress
              ios_tf2.accessibility_label = "Email field"
              ios_row2 << ios_lbl2.as(UI::View)
              ios_row2 << ios_tf2.as(UI::View)
              ios_tf_stack << ios_row2.as(UI::View)

              # Row 3: Password (secure entry)
              ios_row3 = UI::VStack.new(spacing: 4.0)
              ios_row3.alignment = UI::Alignment::Leading
              ios_lbl3 = UI::Label.new("Password:")
              ios_lbl3.font = UI::Font.new(size: 13.0, weight: :regular)
              ios_lbl3.accessibility_label = "Password label"
              ios_tf3 = UI::TextField.new("Password")
              ios_tf3.secure_entry = true
              ios_tf3.text = "secretpassword"
              ios_tf3.minimum_width = 260.0
              ios_tf3.accessibility_label = "Password field"
              ios_row3 << ios_lbl3.as(UI::View)
              ios_row3 << ios_tf3.as(UI::View)
              ios_tf_stack << ios_row3.as(UI::View)

              # Row 4: Numeric (number pad keyboard)
              ios_row4 = UI::VStack.new(spacing: 4.0)
              ios_row4.alignment = UI::Alignment::Leading
              ios_lbl4 = UI::Label.new("Amount:")
              ios_lbl4.font = UI::Font.new(size: 13.0, weight: :regular)
              ios_lbl4.accessibility_label = "Amount label"
              ios_tf4 = UI::TextField.new("0.00")
              ios_tf4.minimum_width = 160.0
              ios_tf4.keyboard_type = UI::KeyboardType::NumberPad
              ios_tf4.accessibility_label = "Amount field"
              ios_row4 << ios_lbl4.as(UI::View)
              ios_row4 << ios_tf4.as(UI::View)
              ios_tf_stack << ios_row4.as(UI::View)

              ios_tf_stack.as(UI::View)
            when "text-views"
              # HIG text-views: multi-line scrollable text on iOS UITextView.
              # HIG Best practices: "Use a text view when you need to display
              # text that's long, editable, or in a special format."
              # iOS / iPadOS: UITextView -- non-editable by default for read-only.

              ios_tv_stack = UI::VStack.new(spacing: 16.0)
              ios_tv_stack << UI::Label.new("HIG: text-views").tap { |l|
                l.font = UI::Font.new(size: 15.0, weight: :semibold)
                l.accessibility_label = "HIG text-views heading"
              }

              # Row 1: Read-only paragraph with line wrapping.
              ios_row1_lbl = UI::Label.new("Read-only paragraph:")
              ios_row1_lbl.font = UI::Font.new(size: 13.0, weight: :regular)
              ios_row1_lbl.accessibility_label = "Read-only paragraph label"
              ios_tv_stack << ios_row1_lbl.as(UI::View)

              ios_tv1 = UI::RichText.new
              ios_tv1.add_span("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.")
              ios_tv1.accessibility_label = "Read-only text view"
              ios_tv_stack << ios_tv1.as(UI::View)

              # Row 2: Attributed text (bold + italic spans).
              ios_row2_lbl = UI::Label.new("Attributed text (bold + italic):")
              ios_row2_lbl.font = UI::Font.new(size: 13.0, weight: :regular)
              ios_row2_lbl.accessibility_label = "Attributed text label"
              ios_tv_stack << ios_row2_lbl.as(UI::View)

              ios_tv2 = UI::RichText.new
              ios_tv2.add_span("The quick brown fox ", bold: false, italic: false)
              ios_tv2.add_span("jumps over", bold: true, italic: false)
              ios_tv2.add_span(" the lazy dog. ", bold: false, italic: false)
              ios_tv2.add_span("Styled text", bold: false, italic: true)
              ios_tv2.add_span(" mixed with plain content wraps across multiple lines.", bold: false, italic: false)
              ios_tv2.accessibility_label = "Attributed text view"
              ios_tv_stack << ios_tv2.as(UI::View)

              ios_tv_stack.as(UI::View)
            when "labels"
              # HIG Labels: 8-row typographic gallery exercising all four
              # LabelRole semantic color tokens (iteration-18 contract) plus
              # the full HIG text-size ladder approximated via font size+weight.
              # LabelRole tokens resolve to UIColor.labelColor /
              # secondaryLabelColor / tertiaryLabelColor / quaternaryLabelColor
              # at render time, tracking light/dark automatically.
              labels_stack = UI::VStack.new(spacing: 10.0)

              # Row 1: Large Title -- Primary, 34pt Bold
              r1_hdr = UI::Label.new("Row 1 (Large Title)")
              r1_hdr.font = UI::Font.new(size: 12.0, weight: :regular)
              r1_hdr.text_color_role = UI::LabelRole::Secondary
              labels_stack << r1_hdr
              r1 = UI::Label.new("The quick brown fox")
              r1.font = UI::Font.new(size: 34.0, weight: :bold)
              r1.text_color_role = UI::LabelRole::Primary
              labels_stack << r1

              # Row 2: Headline -- Primary, 17pt Semibold
              r2_hdr = UI::Label.new("Row 2 (Headline)")
              r2_hdr.font = UI::Font.new(size: 12.0, weight: :regular)
              r2_hdr.text_color_role = UI::LabelRole::Secondary
              labels_stack << r2_hdr
              r2 = UI::Label.new("The quick brown fox")
              r2.font = UI::Font.new(size: 17.0, weight: :semibold)
              r2.text_color_role = UI::LabelRole::Primary
              labels_stack << r2

              # Row 3: Body -- Primary, 17pt Regular
              r3_hdr = UI::Label.new("Row 3 (Body)")
              r3_hdr.font = UI::Font.new(size: 12.0, weight: :regular)
              r3_hdr.text_color_role = UI::LabelRole::Secondary
              labels_stack << r3_hdr
              r3 = UI::Label.new("The quick brown fox")
              r3.font = UI::Font.new(size: 17.0, weight: :regular)
              r3.text_color_role = UI::LabelRole::Primary
              labels_stack << r3

              # Row 4: Callout -- Primary, 16pt Regular
              r4_hdr = UI::Label.new("Row 4 (Callout)")
              r4_hdr.font = UI::Font.new(size: 12.0, weight: :regular)
              r4_hdr.text_color_role = UI::LabelRole::Secondary
              labels_stack << r4_hdr
              r4 = UI::Label.new("The quick brown fox")
              r4.font = UI::Font.new(size: 16.0, weight: :regular)
              r4.text_color_role = UI::LabelRole::Primary
              labels_stack << r4

              # Row 5: Subheadline -- Secondary, 15pt Semibold
              r5_hdr = UI::Label.new("Row 5 (Subheadline, Secondary color)")
              r5_hdr.font = UI::Font.new(size: 12.0, weight: :regular)
              r5_hdr.text_color_role = UI::LabelRole::Secondary
              labels_stack << r5_hdr
              r5 = UI::Label.new("The quick brown fox")
              r5.font = UI::Font.new(size: 15.0, weight: :semibold)
              r5.text_color_role = UI::LabelRole::Secondary
              labels_stack << r5

              # Row 6: Footnote -- Tertiary, 13pt Regular
              r6_hdr = UI::Label.new("Row 6 (Footnote, Tertiary color)")
              r6_hdr.font = UI::Font.new(size: 12.0, weight: :regular)
              r6_hdr.text_color_role = UI::LabelRole::Secondary
              labels_stack << r6_hdr
              r6 = UI::Label.new("The quick brown fox")
              r6.font = UI::Font.new(size: 13.0, weight: :regular)
              r6.text_color_role = UI::LabelRole::Tertiary
              labels_stack << r6

              # Row 7: Caption -- Quaternary, 12pt Regular
              r7_hdr = UI::Label.new("Row 7 (Caption, Quaternary color)")
              r7_hdr.font = UI::Font.new(size: 12.0, weight: :regular)
              r7_hdr.text_color_role = UI::LabelRole::Secondary
              labels_stack << r7_hdr
              r7 = UI::Label.new("THE QUICK BROWN FOX")
              r7.font = UI::Font.new(size: 12.0, weight: :regular)
              r7.text_color_role = UI::LabelRole::Quaternary
              labels_stack << r7

              # Row 8: Multi-line wrapping Body -- Primary, 17pt Regular
              r8_hdr = UI::Label.new("Row 8 (Multi-line Body, Primary color)")
              r8_hdr.font = UI::Font.new(size: 12.0, weight: :regular)
              r8_hdr.text_color_role = UI::LabelRole::Secondary
              labels_stack << r8_hdr
              r8 = UI::Label.new("The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs. How vexingly quick daft zebras jump!")
              r8.font = UI::Font.new(size: 17.0, weight: :regular)
              r8.text_color_role = UI::LabelRole::Primary
              r8.number_of_lines = 0
              labels_stack << r8

              labels_stack.as(UI::View)
            when "sliders"
              # HIG Sliders: UISlider -- horizontal track, filled leading portion in
              # minimumTrackTintColor, circular rubber thumb.
              # Best practices: "Customize a slider's appearance if it adds value."
              # Best practices: "Use familiar slider directions" -- min leading, max trailing.
              # Showcase: four variants -- plain, labeled, volume-style SF Symbol, tinted.

              ios_sliders_stack = UI::VStack.new(spacing: 20.0)

              # Section title
              ios_sl_title = UI::Label.new("Sliders -- UISlider")
              ios_sl_title.font = UI::Font.new(size: 15.0, weight: :semibold)
              ios_sl_title.text_color_role = UI::LabelRole::Primary
              ios_sl_title.accessibility_label = "Sliders showcase title"
              ios_sliders_stack << ios_sl_title

              # Variant 1: Plain slider at 40%
              ios_v1_cap = UI::Label.new("Plain slider (40% value, default tint)")
              ios_v1_cap.font = UI::Font.new(size: 11.0, weight: :regular)
              ios_v1_cap.text_color_role = UI::LabelRole::Secondary
              ios_v1_cap.accessibility_label = "Plain slider caption"
              ios_sliders_stack << ios_v1_cap

              ios_plain = UI::Slider.new(0.0, 100.0, 40.0)
              ios_plain.accessibility_label = "Plain slider at 40 percent"
              ios_sliders_stack << ios_plain

              # Variant 2: Labeled slider with min/max text and current value
              ios_v2_cap = UI::Label.new("Slider with min / max text labels")
              ios_v2_cap.font = UI::Font.new(size: 11.0, weight: :regular)
              ios_v2_cap.text_color_role = UI::LabelRole::Secondary
              ios_v2_cap.accessibility_label = "Labeled slider caption"
              ios_sliders_stack << ios_v2_cap

              ios_labeled_row = UI::HStack.new(spacing: 8.0)
              ios_min_lbl = UI::Label.new("0")
              ios_min_lbl.font = UI::Font.new(size: 13.0, weight: :regular)
              ios_min_lbl.text_color_role = UI::LabelRole::Secondary
              ios_labeled_row << ios_min_lbl

              ios_labeled_sl = UI::Slider.new(0.0, 100.0, 65.0)
              ios_labeled_sl.accessibility_label = "Brightness slider at 65 percent"
              ios_labeled_row << ios_labeled_sl

              ios_max_lbl = UI::Label.new("100")
              ios_max_lbl.font = UI::Font.new(size: 13.0, weight: :regular)
              ios_max_lbl.text_color_role = UI::LabelRole::Secondary
              ios_labeled_row << ios_max_lbl
              ios_sliders_stack << ios_labeled_row

              ios_val_lbl = UI::Label.new("Current value: 65")
              ios_val_lbl.font = UI::Font.new(size: 11.0, weight: :regular)
              ios_val_lbl.text_color_role = UI::LabelRole::Tertiary
              ios_val_lbl.accessibility_label = "Current slider value label"
              ios_sliders_stack << ios_val_lbl

              # Variant 3: Volume-style slider with SF Symbol icons
              ios_v3_cap = UI::Label.new("Volume-style slider (SF Symbols)")
              ios_v3_cap.font = UI::Font.new(size: 11.0, weight: :regular)
              ios_v3_cap.text_color_role = UI::LabelRole::Secondary
              ios_v3_cap.accessibility_label = "Volume slider caption"
              ios_sliders_stack << ios_v3_cap

              ios_vol_row = UI::HStack.new(spacing: 8.0)
              ios_vol_min = UI::Image.new("speaker.slash")
              ios_vol_min.accessibility_label = "Speaker off"
              ios_vol_row << ios_vol_min

              ios_vol_sl = UI::Slider.new(0.0, 1.0, 0.55)
              ios_vol_sl.accessibility_label = "Volume slider at 55 percent"
              ios_vol_row << ios_vol_sl

              ios_vol_max = UI::Image.new("speaker.wave.3")
              ios_vol_max.accessibility_label = "Speaker full volume"
              ios_vol_row << ios_vol_max
              ios_sliders_stack << ios_vol_row

              # Variant 4: Tinted slider (brand orange)
              ios_v4_cap = UI::Label.new("Tinted slider (brand accent override -- orange)")
              ios_v4_cap.font = UI::Font.new(size: 11.0, weight: :regular)
              ios_v4_cap.text_color_role = UI::LabelRole::Secondary
              ios_v4_cap.accessibility_label = "Tinted slider caption"
              ios_sliders_stack << ios_v4_cap

              ios_tinted = UI::Slider.new(0.0, 100.0, 75.0)
              ios_tinted.tint_color = UI::Color.new(r: 1.0, g: 0.584, b: 0.0)
              ios_tinted.accessibility_label = "Tinted slider at 75 percent"
              ios_sliders_stack << ios_tinted

              ios_sliders_stack.as(UI::View)
            when "steppers"
              # HIG: "A stepper is a two-segment control that people use to increase or
              # decrease an incremental value." UIStepper renders as a pill-shaped +/-
              # control. Pair with a Label -- the control never displays its own value.
              # HIG: "Make the value that a stepper affects obvious."
              # UIStepper automatically disables (dims) the minus segment when value == minimum
              # and the plus segment when value == maximum -- native UIKit behaviour.

              ios_steppers_title = UI::Label.new("Steppers -- UIStepper")
              ios_steppers_title.font = UI::Font.new(size: 15.0, weight: :medium)
              ios_steppers_title.accessibility_label = "Steppers showcase title"

              # Row 1: normal state, value 3, range 0-10
              ios_row1_label = UI::Label.new("Quantity: 3")
              ios_row1_label.font = UI::Font.new(size: 13.0, weight: :regular)
              ios_row1_label.accessibility_label = "Quantity label, value 3"

              ios_row1_stepper = UI::Stepper.new(0.0, 10.0, 3.0)
              ios_row1_stepper.step_value = 1.0
              ios_row1_stepper.accessibility_label = "Quantity stepper, value 3"

              ios_row1 = UI::HStack.new(spacing: 8.0)
              ios_row1 << ios_row1_label
              ios_row1 << ios_row1_stepper

              # Row 2: at minimum -- minus segment auto-dimmed by UIStepper
              ios_row2_label = UI::Label.new("At minimum: 0")
              ios_row2_label.font = UI::Font.new(size: 13.0, weight: :regular)
              ios_row2_label.accessibility_label = "At minimum label, value 0"

              ios_row2_stepper = UI::Stepper.new(0.0, 10.0, 0.0)
              ios_row2_stepper.step_value = 1.0
              ios_row2_stepper.accessibility_label = "Stepper at minimum, value 0, minus disabled"

              ios_row2 = UI::HStack.new(spacing: 8.0)
              ios_row2 << ios_row2_label
              ios_row2 << ios_row2_stepper

              # Row 3: at maximum -- plus segment auto-dimmed by UIStepper
              ios_row3_label = UI::Label.new("At maximum: 10")
              ios_row3_label.font = UI::Font.new(size: 13.0, weight: :regular)
              ios_row3_label.accessibility_label = "At maximum label, value 10"

              ios_row3_stepper = UI::Stepper.new(0.0, 10.0, 10.0)
              ios_row3_stepper.step_value = 1.0
              ios_row3_stepper.accessibility_label = "Stepper at maximum, value 10, plus disabled"

              ios_row3 = UI::HStack.new(spacing: 8.0)
              ios_row3 << ios_row3_label
              ios_row3 << ios_row3_stepper

              ios_steppers_stack = UI::VStack.new(spacing: 16.0)
              ios_steppers_stack << ios_steppers_title
              ios_steppers_stack << ios_row1
              ios_steppers_stack << ios_row2
              ios_steppers_stack << ios_row3

              ios_steppers_stack.as(UI::View)
            when "segmented-controls"
              # HIG: "A segmented control is a linear set of two or more segments,
              # each of which functions as a button." UISegmentedControl renders as
              # a pill-shaped grouped control; the selected segment has a filled
              # backing (system-tinted on iOS 26) in both light and dark appearances.
              # Showcase: text-only (Day/Week/Month, Week selected at index 1) plus
              # an icon-label variant (4 segments, index 1 selected).
              # HIG: "Limit the number of segments in a control." -- 3 and 4 here.
              # HIG: "Use nouns or noun phrases for segment labels."

              ios_sc_title = UI::Label.new("Segmented Controls -- UISegmentedControl")
              ios_sc_title.font = UI::Font.new(size: 15.0, weight: :medium)
              ios_sc_title.accessibility_label = "Segmented Controls showcase title"

              ios_sc_text_caption = UI::Label.new("Text segments (Week selected, index 1)")
              ios_sc_text_caption.font = UI::Font.new(size: 11.0, weight: :regular)
              ios_sc_text_caption.accessibility_label = "Text segments caption"

              # Text-only: 3 segments, index 1 (Week) selected -- HIG-aligned default
              ios_sc_text = UI::SegmentedControl.new(["Day", "Week", "Month"], 1)
              ios_sc_text.accessibility_label = "Day Week Month segmented control"

              ios_sc_icon_caption = UI::Label.new("Icon-label segments (4 segments, index 1 selected)")
              ios_sc_icon_caption.font = UI::Font.new(size: 11.0, weight: :regular)
              ios_sc_icon_caption.accessibility_label = "Icon segments caption"

              # Icon variant: 4 segments using SF Symbol names as labels, index 1 selected
              ios_sc_icon = UI::SegmentedControl.new(
                ["list.bullet", "grid.2x2", "grid.3x3", "square.3.stack.3d"], 1
              )
              ios_sc_icon.accessibility_label = "Icon segmented control"

              ios_sc_outer = UI::VStack.new(spacing: 10.0)
              ios_sc_outer << ios_sc_title
              ios_sc_outer << ios_sc_text_caption
              ios_sc_outer << ios_sc_text
              ios_sc_outer << ios_sc_icon_caption
              ios_sc_outer << ios_sc_icon
              ios_sc_outer.as(UI::View)
            when "progress-indicators"
              # HIG: "Progress indicators let people know that your app isn't
              # stalled while it loads content or performs lengthy operations."
              # Gallery: spinner (medium), spinner (large, tinted), linear
              # determinate at 60%, linear indeterminate, labeled upload row
              # with cancel button.
              # HIG: "When possible, use a determinate progress indicator."
              # HIG: "If it's helpful, display a description that provides
              # additional context for the task."
              ios_gallery = UI::VStack.new(spacing: 16.0)
              ios_gallery.alignment = UI::Alignment::Leading
              ios_gallery.minimum_width = 330.0
              ios_gallery.maximum_width = 330.0
              ios_gallery.padding = UI::EdgeInsets.new(top: 12.0, trailing: 20.0, bottom: 12.0, leading: 20.0)

              # --- Section: Spinners ---
              ios_spinner_hdr = UI::Label.new("Spinners (indeterminate)")
              ios_spinner_hdr.font = UI::Font.new(size: 15.0, weight: :semibold)
              ios_spinner_hdr.accessibility_label = "Spinners section header"
              ios_gallery << ios_spinner_hdr

              ios_spinner_row = UI::HStack.new(spacing: 32.0)

              # Medium spinner (UIActivityIndicatorViewStyle.medium = 100)
              ios_med = UI::ActivityIndicator.new(true, :medium)
              ios_med.accessibility_label = "Loading indicator medium"
              ios_spinner_row << ios_med

              # Large spinner, tinted with the Amber role color.
              ios_lg = UI::ActivityIndicator.new(true, :large)
              ios_lg.color = UI::Color.new(r: 1.0, g: 0.678, b: 0.2, a: 1.0)
              ios_lg.accessibility_label = "Loading indicator large"
              ios_spinner_row << ios_lg

              ios_gallery << ios_spinner_row

              # --- Section: Linear determinate at 60% ---
              ios_bar_hdr = UI::Label.new("Linear progress (determinate)")
              ios_bar_hdr.font = UI::Font.new(size: 15.0, weight: :semibold)
              ios_bar_hdr.accessibility_label = "Linear progress section header"
              ios_gallery << ios_bar_hdr

              ios_det_bar = UI::ProgressView.new(0.6, UI::ProgressStyle::Linear)
              ios_det_bar.label = "Uploading... 60%"
              ios_det_bar.minimum_width = 260.0
              ios_det_bar.accessibility_label = "Upload progress 60 percent"
              ios_gallery << ios_det_bar

              ios_det_lbl = UI::Label.new("Uploading... 60%")
              ios_det_lbl.font = UI::Font.new(size: 15.0, weight: :regular)
              ios_det_lbl.accessibility_label = "Upload progress label"
              ios_gallery << ios_det_lbl

              # --- Section: Linear indeterminate ---
              ios_indet_hdr = UI::Label.new("Linear progress (indeterminate)")
              ios_indet_hdr.font = UI::Font.new(size: 15.0, weight: :semibold)
              ios_indet_hdr.accessibility_label = "Indeterminate progress section header"
              ios_gallery << ios_indet_hdr

              ios_indet_bar = UI::ProgressView.new(nil, UI::ProgressStyle::Linear)
              ios_indet_bar.label = "Syncing..."
              ios_indet_bar.minimum_width = 260.0
              ios_indet_bar.accessibility_label = "Syncing progress indeterminate"
              ios_gallery << ios_indet_bar

              ios_indet_lbl = UI::Label.new("Syncing...")
              ios_indet_lbl.font = UI::Font.new(size: 15.0, weight: :regular)
              ios_indet_lbl.accessibility_label = "Syncing status label"
              ios_gallery << ios_indet_lbl

              # --- Section: Labeled upload row with cancel ---
              ios_upload_hdr = UI::Label.new("Determinate with cancel")
              ios_upload_hdr.font = UI::Font.new(size: 15.0, weight: :semibold)
              ios_upload_hdr.accessibility_label = "Upload with cancel section header"
              ios_gallery << ios_upload_hdr

              ios_upload_row = UI::HStack.new(spacing: 12.0)
              ios_upload_row.alignment = UI::Alignment::Center
              ios_upload_lbl = UI::Label.new("Uploading file.zip")
              ios_upload_lbl.font = UI::Font.new(size: 15.0, weight: :regular)
              ios_upload_lbl.accessibility_label = "Upload filename"
              ios_upload_row << ios_upload_lbl
              ios_upload_row << UI::Spacer.new.as(UI::View)
              ios_cancel_btn = UI::Button.new("Cancel")
              ios_cancel_btn.role = :cancel
              ios_cancel_btn.accessibility_label = "Cancel upload"
              ios_upload_row << ios_cancel_btn
              ios_gallery << ios_upload_row
              ios_upload_bar = UI::ProgressView.new(0.6, UI::ProgressStyle::Linear)
              ios_upload_bar.minimum_width = 260.0
              ios_gallery << ios_upload_bar.as(UI::View)

              ios_gallery.as(UI::View)
            when "activity-indicators" then UI::ActivityIndicator.new(true, :medium).as(UI::View)
            when "popovers"
              # HIG: "A popover is a transient view that appears above other content
              # when people click or tap a control or interactive area."
              # HIG Best practices: "Use a popover to expose a small amount of
              # information or functionality." -- Popovers / Best practices.
              #
              # Rendered inline (is_presented == false) for screenshot isolation.
              # Content: realistic filter panel -- title + two radio-style picker
              # options + "Clear filters" button at bottom. Mirrors the macOS arm.
              # iOS 26: UIVisualEffectView(UIGlassEffect) or UIBlurEffect(style:11)
              # wrapping a UIStackView, corner radius ~10pt.
              ios_popover_content = UI::VStack.new(spacing: 12.0)

              ios_filter_title = UI::Label.new("Filter")
              ios_filter_title.font = UI::Font.new(size: 15.0, weight: :semibold)
              ios_filter_title.accessibility_label = "Filter panel title"
              ios_popover_content << ios_filter_title

              ios_pop_div = UI::Divider.new(:horizontal)
              ios_popover_content << ios_pop_div

              ios_sort_label = UI::Label.new("Sort by")
              ios_sort_label.font = UI::Font.new(size: 12.0, weight: :semibold)
              ios_sort_label.text_color = UI::Color.new(r: 0.55, g: 0.55, b: 0.55)
              ios_sort_label.accessibility_label = "Sort by label"
              ios_popover_content << ios_sort_label

              ios_sort_picker = UI::Picker.new(["Newest first", "Oldest first"], 0)
              ios_sort_picker.style = UI::PickerStyle::Segmented
              ios_sort_picker.accessibility_label = "Sort order picker"
              ios_popover_content << ios_sort_picker

              ios_vault_label = UI::Label.new("Vault")
              ios_vault_label.font = UI::Font.new(size: 12.0, weight: :semibold)
              ios_vault_label.text_color = UI::Color.new(r: 0.55, g: 0.55, b: 0.55)
              ios_vault_label.accessibility_label = "Vault filter label"
              ios_popover_content << ios_vault_label

              ios_vault_picker = UI::Picker.new(["Morning Pages", "All vaults"], 1)
              ios_vault_picker.style = UI::PickerStyle::Segmented
              ios_vault_picker.accessibility_label = "Vault filter picker"
              ios_popover_content << ios_vault_picker

              ios_pop_div2 = UI::Divider.new(:horizontal)
              ios_popover_content << ios_pop_div2

              ios_clear_btn = UI::Button.new("Clear filters", role: :default)
              ios_clear_btn.accessibility_label = "Clear filters"
              ios_popover_content << ios_clear_btn

              UI::Popover.new(ios_popover_content.as(UI::View), :bottom).as(UI::View)
            when "pickers"
              # HIG: "For short lists, consider using a menu or segmented control
              # instead of a wheel picker." iOS renderer uses inline-list-with-
              # checkmarks (iOS Settings style) for static option sets. This is
              # legible in both light and dark appearances with no data-source wiring.
              picker_options = ["United States", "Canada", "Mexico",
                                "United Kingdom", "Germany"]
              picker = UI::Picker.new(picker_options, 0)
              picker.label = "Country"
              picker.accessibility_label = "Country picker"

              container = UI::VStack.new(spacing: 16.0)
              container << UI::Label.new("Select a country")
              container << picker
              container.as(UI::View)
            when "pop-up-buttons"
              # HIG: "Use a pop-up button to present a flat list of mutually
              # exclusive options or states."  iOS renders a UIButton capsule
              # with current selection label + trailing chevron.up.chevron.down.
              ios_container = UI::VStack.new(spacing: 20.0)

              # Row 1: Alignment pop-up
              ios_row1_label = UI::Label.new("Alignment:")
              ios_row1_label.font = UI::Font.new(size: 15.0, weight: :regular)
              ios_row1_btn = UI::MenuButton.new("Alignment")
              ios_row1_btn.add_item("Left")
              ios_row1_btn.add_item("Center")
              ios_row1_btn.add_item("Right")
              ios_row1_btn.add_item("Justified")
              ios_row1_btn.selected_index = 0
              ios_row1_btn.accessibility_label = "Alignment, pop-up button"
              ios_row1 = UI::HStack.new(spacing: 8.0)
              ios_row1 << ios_row1_label
              ios_row1 << ios_row1_btn
              ios_container << ios_row1

              # Row 2: Font size pop-up (12pt selected)
              ios_row2_label = UI::Label.new("Font size:")
              ios_row2_label.font = UI::Font.new(size: 15.0, weight: :regular)
              ios_row2_btn = UI::MenuButton.new("Font size")
              ios_row2_btn.add_item("9pt")
              ios_row2_btn.add_item("10pt")
              ios_row2_btn.add_item("11pt")
              ios_row2_btn.add_item("12pt")
              ios_row2_btn.add_item("14pt")
              ios_row2_btn.add_item("18pt")
              ios_row2_btn.selected_index = 3
              ios_row2_btn.accessibility_label = "Font size, pop-up button"
              ios_row2 = UI::HStack.new(spacing: 8.0)
              ios_row2 << ios_row2_label
              ios_row2 << ios_row2_btn
              ios_container << ios_row2

              # Row 3: Theme pop-up (Auto selected)
              ios_row3_label = UI::Label.new("Theme:")
              ios_row3_label.font = UI::Font.new(size: 15.0, weight: :regular)
              ios_row3_btn = UI::MenuButton.new("Theme")
              ios_row3_btn.add_item("Auto")
              ios_row3_btn.add_item("Light")
              ios_row3_btn.add_item("Dark")
              ios_row3_btn.selected_index = 0
              ios_row3_btn.accessibility_label = "Theme, pop-up button"
              ios_row3 = UI::HStack.new(spacing: 8.0)
              ios_row3 << ios_row3_label
              ios_row3 << ios_row3_btn
              ios_container << ios_row3

              ios_container.as(UI::View)
            when "pull-down-buttons"
              # HIG: "A pull-down button displays a menu of items or actions
              # that directly relate to the button's purpose."  On iOS, renders
              # as a UIButton with showsMenuAsPrimaryAction + chevron.down.
              # No selected-state label; no chevron.up component.
              # Three patterns:
              #   1. "Add" -- content-creation actions.
              #   2. Ellipsis "..." -- more-actions for the current item.
              #   3. "Export" (prominent / filledButtonConfiguration) --
              #      toolbar export format chooser.
              ios_pd_container = UI::VStack.new(spacing: 20.0)

              # --- 1. Add pull-down ---
              ios_pd_ctx1 = UI::Label.new("Content actions:")
              ios_pd_ctx1.font = UI::Font.new(size: 15.0, weight: :regular)
              ios_add_btn = UI::MenuButton.new("Add")
              ios_add_btn.is_pull_down = true
              ios_add_btn.add_item("New Folder")
              ios_add_btn.add_item("New Document")
              ios_add_btn.add_item("New Template")
              ios_add_btn.add_item("Import\u2026")
              ios_add_btn.accessibility_label = "Add, pull-down button"
              ios_pd_row1 = UI::HStack.new(spacing: 8.0)
              ios_pd_row1 << ios_pd_ctx1
              ios_pd_row1 << ios_add_btn
              ios_pd_container << ios_pd_row1

              # --- 2. Ellipsis more-actions ---
              ios_pd_ctx2 = UI::Label.new("Item actions:")
              ios_pd_ctx2.font = UI::Font.new(size: 15.0, weight: :regular)
              ios_more_btn = UI::MenuButton.new("\u2026")
              ios_more_btn.is_pull_down = true
              ios_more_btn.add_item("Duplicate")
              ios_more_btn.add_item("Rename")
              ios_more_btn.add_item("Move\u2026")
              ios_more_btn.add_item("Delete", is_destructive: true)
              ios_more_btn.accessibility_label = "More actions, pull-down button"
              ios_pd_row2 = UI::HStack.new(spacing: 8.0)
              ios_pd_row2 << ios_pd_ctx2
              ios_pd_row2 << ios_more_btn
              ios_pd_container << ios_pd_row2

              # --- 3. Export pull-down (prominent) ---
              ios_pd_ctx3 = UI::Label.new("Toolbar export:")
              ios_pd_ctx3.font = UI::Font.new(size: 15.0, weight: :regular)
              ios_export_btn = UI::MenuButton.new("Export")
              ios_export_btn.is_pull_down = true
              ios_export_btn.button_style = :prominent
              ios_export_btn.add_item("PDF")
              ios_export_btn.add_item("CSV")
              ios_export_btn.add_item("HTML")
              ios_export_btn.add_item("Markdown")
              ios_export_btn.accessibility_label = "Export, pull-down button"
              ios_pd_row3 = UI::HStack.new(spacing: 8.0)
              ios_pd_row3 << ios_pd_ctx3
              ios_pd_row3 << ios_export_btn
              ios_pd_container << ios_pd_row3

              ios_pd_container.as(UI::View)
            when "scroll-views"
              # HIG: "A scroll view lets people view content that's larger than
              # the view's boundaries by moving the content vertically or
              # horizontally."  Showcase: UIScrollView containing a UIStackView
              # of 15 numbered rows. Content height (~15 * 44pt = ~660pt)
              # exceeds the clipping frame (~320pt), making the scroll boundary
              # plainly visible.
              ios_sv_title = UI::Label.new("HIG: scroll-views")
              ios_sv_title.font = UI::Font.new(size: 20.0, weight: :medium)
              ios_sv_title.accessibility_label = "scroll-views showcase title"

              ios_sv_content = UI::VStack.new(spacing: 0.0)
              (1..15).each do |i|
                row_lbl = UI::Label.new("Item #{i} \u2014 scrollable content row")
                row_lbl.font = UI::Font.new(size: 16.0, weight: :regular)
                row_lbl.accessibility_label = "Scroll row #{i}"
                ios_sv_content << row_lbl
                if i < 15
                  ios_sv_content << UI::Divider.new
                end
              end

              # frame_height=320 pins the UIScrollView viewport height inside
              # the parent UIStackView; the content UIStackView (~15 rows *
              # 44pt = ~660pt) is taller than the viewport.
              ios_scroll = UI::ScrollView.new(ios_sv_content)
              ios_scroll.scroll_vertical = true
              ios_scroll.scroll_horizontal = false
              ios_scroll.shows_indicators = true
              ios_scroll.frame_height = 320.0
              ios_scroll.accessibility_label = "Vertical scroll view with 15 rows"

              ios_sv_outer = UI::VStack.new(spacing: 12.0)
              ios_sv_outer << ios_sv_title
              ios_sv_outer << ios_scroll
              ios_sv_outer.as(UI::View)
            when "toolbars"
              # HIG: "A toolbar provides convenient access to frequently used
              # commands, controls, navigation, and search." On iOS 26,
              # toolbars use UIGlassEffect / UIBlurEffect systemChromeMaterial
              # as the glass background. Items are icon-only UIButtons (44x44pt
              # hit targets, no circular borders per HIG Best practices).
              #
              # Showcase: Mail-style bottom action bar with 5 items + divider.
              # compose | archive | flag | trash(destructive) | reply
              #
              # HIG Best practices:
              #   "Prefer system-provided symbols without borders."
              #   "Prioritize only the most important items for inclusion in
              #    the main toolbar area." (iOS)

              ios_tb = UI::Toolbar.new
              ios_tb.accessibility_label = "Mail action toolbar"

              ios_tb.add_item("compose",  "Compose",  "square.and.pencil")
              ios_tb.add_item("archive",  "Archive",  "archivebox")
              ios_tb.add_item("sep1",     "---",      nil)
              ios_tb.add_item("flag",     "Flag",     "flag")
              ios_tb.add_item("trash",    "Delete",   "trash")
              ios_tb.add_item("reply",    "Reply",    "arrowshape.turn.up.left")

              ios_tb_heading = UI::Label.new("HIG: toolbars (iOS UIToolbar)")
              ios_tb_heading.font = UI::Font.new(size: 15.0, weight: :semibold)
              ios_tb_heading.accessibility_label = "Toolbars showcase heading"

              ios_tb_desc = UI::Label.new("Liquid Glass toolbar — icon items, 44pt hit targets")
              ios_tb_desc.font = UI::Font.new(size: 13.0, weight: :regular)
              ios_tb_desc.accessibility_label = "Toolbars showcase description"

              ios_tb_outer = UI::VStack.new(spacing: 12.0)
              ios_tb_outer << ios_tb_heading
              ios_tb_outer << ios_tb
              ios_tb_outer << ios_tb_desc
              ios_tb_outer.as(UI::View)
            when "search-fields"
              # HIG: "A search field lets people search a collection of content
              # for specific terms they enter." UISearchBar provides the
              # magnifying-glass leading icon, pill-shaped rounded field,
              # placeholder text in secondary color, and shows a trailing clear
              # button when text is present.
              # Showcase: two states side-by-side — empty (placeholder) and
              # filled (text + clear button visible).

              ios_sf_title = UI::Label.new("Search Fields — UISearchBar")
              ios_sf_title.font = UI::Font.new(size: 15.0, weight: :medium)
              ios_sf_title.accessibility_label = "Search Fields showcase title"

              # State 1: empty — placeholder in secondary color
              ios_sf_empty_label = UI::Label.new("Empty (placeholder visible)")
              ios_sf_empty_label.font = UI::Font.new(size: 11.0, weight: :regular)
              ios_sf_empty_label.accessibility_label = "Empty search field caption"

              ios_sf_empty = UI::SearchField.new("Shows, Movies, and More")
              ios_sf_empty.text = ""
              ios_sf_empty.shows_cancel_button = false
              ios_sf_empty.accessibility_label = "Empty search field"

              # State 2: filled — text in primary color, trailing clear button
              ios_sf_filled_label = UI::Label.new("Filled (clear button visible)")
              ios_sf_filled_label.font = UI::Font.new(size: 11.0, weight: :regular)
              ios_sf_filled_label.accessibility_label = "Filled search field caption"

              ios_sf_filled = UI::SearchField.new("Shows, Movies, and More")
              ios_sf_filled.text = "Apple HIG"
              ios_sf_filled.shows_cancel_button = true
              ios_sf_filled.accessibility_label = "Filled search field with Apple HIG query"

              ios_sf_outer = UI::VStack.new(spacing: 10.0)
              ios_sf_outer << ios_sf_title
              ios_sf_outer << ios_sf_empty_label
              ios_sf_outer << ios_sf_empty
              ios_sf_outer << ios_sf_filled_label
              ios_sf_outer << ios_sf_filled
              ios_sf_outer.as(UI::View)
            when "sidebars"
              # iPhone: HIG Sidebars — Platform considerations: "Avoid using a
              # sidebar on iPhone." On iPhone, replace the sidebar with a bottom
              # tab bar (UITabBarController) per HIG guidance.
              # Four destinations: Memories / Rituals / Vault / Profile.
              # UITabBarController renders with Liquid Glass bottom bar per iOS 26
              # HIG: "A tab bar floats above content at the bottom of the screen."
              # Amber gold selected tint (UITabBar.tintColor = amberGold).
              # Debug "HIG: <slug>" label removed per Issue B.
              #
              # Sizing: minimum_width=375, minimum_height=812 (standard iPhone
              # viewport) forces the outer VStack in build_focal to expand to
              # full-screen so the tab bar anchors to the bottom edge correctly.
              # Without explicit minimum dimensions the UIStackView wrapper sizes
              # to intrinsic content width, producing the "35% float" bug.
              ios_amber_gold = UI::Color.new(r: 1.0, g: 0.678, b: 0.2)
              ios_gray_sec   = UI::Color.new(r: 0.55, g: 0.55, b: 0.55)

              # Memories tab: real Amber message rows (same 5 as macOS)
              ios_memories_content = UI::VStack.new(spacing: 0.0)
              ios_memories_content.alignment = UI::Alignment::Leading

              ios_mem_nav_lbl = UI::Label.new("Memories")
              ios_mem_nav_lbl.font = UI::Font.new(size: 17.0, weight: :semibold)
              ios_mem_nav_lbl.accessibility_label = "Memories navigation title"
              ios_mem_nav_lbl.padding = UI::EdgeInsets.new(top: 12.0, trailing: 16.0, bottom: 8.0, leading: 16.0)
              ios_memories_content << ios_mem_nav_lbl.as(UI::View)

              [
                {true,  "Amber",     "Morning pages unlocked",         "Your 3-page ritual is complete. Amber noticed the shift.", "9:14"},
                {true,  "Rituals",   "5 rituals due tomorrow",         "Morning pages, breathwork, evening review, and 2 more.",   "Tue"},
                {false, "Vault",     "248 artifacts archived",         "Your vault is thriving. The rift is stable.",              "Sun"},
                {false, "Deep Work", "2h 14m today \u00B7 new record", "You outran yesterday's session. Amber is holding the streak.", "Apr 13"},
                {false, "Amber",     "Memory synced across rift",      "Your vault is up to date. Nothing was lost.",             "Apr 12"},
              ].each_with_index do |(unread, sender, subject, preview, ts), idx|
                if idx > 0
                  ios_row_sep = UI::Divider.new(:horizontal)
                  ios_row_sep.accessibility_label = "Message separator"
                  ios_memories_content << ios_row_sep
                end

                ios_avatar = UI::Image.new("person.circle.fill")
                ios_avatar.tint_color = ios_amber_gold
                ios_avatar.minimum_width = 32.0
                ios_avatar.minimum_height = 32.0
                ios_avatar.content_mode = UI::ContentMode::Fit
                ios_avatar.accessibility_label = "#{sender} avatar"

                ios_sender_lbl = UI::Label.new(sender)
                ios_sender_lbl.font = UI::Font.new(size: 15.0, weight: unread ? :semibold : :regular)
                ios_sender_lbl.accessibility_label = "From #{sender}"

                ios_subject_lbl = UI::Label.new(subject)
                ios_subject_lbl.font = UI::Font.new(size: 13.0, weight: unread ? :semibold : :regular)
                ios_subject_lbl.accessibility_label = "Subject: #{subject}"

                ios_preview_lbl = UI::Label.new(preview)
                ios_preview_lbl.font = UI::Font.new(size: 12.0, weight: :regular)
                ios_preview_lbl.text_color = ios_gray_sec
                ios_preview_lbl.accessibility_label = "Preview"

                ios_text_col = UI::VStack.new(spacing: 1.0)
                ios_text_col << ios_sender_lbl.as(UI::View)
                ios_text_col << ios_subject_lbl.as(UI::View)
                ios_text_col << ios_preview_lbl.as(UI::View)

                ios_ts_lbl = UI::Label.new(ts)
                ios_ts_lbl.font = UI::Font.new(size: 11.0, weight: :regular)
                ios_ts_lbl.text_color = ios_gray_sec
                ios_ts_lbl.accessibility_label = "Received #{ts}"

                ios_msg_row = UI::HStack.new(spacing: 8.0)
                ios_msg_row << ios_avatar.as(UI::View)
                ios_msg_row << ios_text_col.as(UI::View)
                ios_msg_row << UI::Spacer.new.as(UI::View)
                ios_msg_row << ios_ts_lbl.as(UI::View)
                ios_msg_row.minimum_height = 68.0
                ios_msg_row.padding = UI::EdgeInsets.new(top: 10.0, trailing: 16.0, bottom: 10.0, leading: 16.0)
                ios_msg_row.accessibility_label = "Message from #{sender}: #{subject}"
                ios_memories_content << ios_msg_row
              end

              ios_rituals_content = UI::VStack.new(spacing: 8.0)
              ios_rit_lbl = UI::Label.new("Rituals")
              ios_rit_lbl.font = UI::Font.new(size: 17.0, weight: :semibold)
              ios_rit_lbl.accessibility_label = "Rituals tab content"
              ios_rituals_content << ios_rit_lbl.as(UI::View)

              ios_vault_content = UI::VStack.new(spacing: 8.0)
              ios_vlt_lbl = UI::Label.new("Vault")
              ios_vlt_lbl.font = UI::Font.new(size: 17.0, weight: :semibold)
              ios_vlt_lbl.accessibility_label = "Vault tab content"
              ios_vault_content << ios_vlt_lbl.as(UI::View)

              ios_profile_content = UI::VStack.new(spacing: 8.0)
              ios_pro_lbl = UI::Label.new("Profile")
              ios_pro_lbl.font = UI::Font.new(size: 17.0, weight: :semibold)
              ios_pro_lbl.accessibility_label = "Profile tab content"
              ios_profile_content << ios_pro_lbl.as(UI::View)

              ios_tabview = UI::TabView.new(
                tabs: [
                  UI::TabView::Tab.new(label: "Memories", icon: "tray.fill",          content: ios_memories_content.as(UI::View)),
                  UI::TabView::Tab.new(label: "Rituals",  icon: "sparkles",            content: ios_rituals_content.as(UI::View)),
                  UI::TabView::Tab.new(label: "Vault",    icon: "shippingbox",         content: ios_vault_content.as(UI::View)),
                  UI::TabView::Tab.new(label: "Profile",  icon: "person.crop.circle",  content: ios_profile_content.as(UI::View)),
                ],
                selected_index: 0
              )
              ios_tabview.selected_tint_color = ios_amber_gold
              ios_tabview.glass_bar = true
              ios_tabview.bar_position = :bottom
              # Full-viewport sizing: forces the build_focal VStack wrapper to
              # expand to screen dimensions so the tab bar anchors to the bottom.
              # Without this, UIStackView sizes to intrinsic content width (~35%).
              ios_tabview.minimum_width  = 375.0
              ios_tabview.minimum_height = 812.0
              ios_tabview.maximum_width  = 375.0
              ios_tabview.maximum_height = 812.0
              # Background: resolve dark vs light to eliminate the 20pt peach/amber
              # band at viewport top + bottom (June R3). The band appears because the
              # outer build_focal VStack has 16pt spacing which shows the window
              # background. Setting the TabView background to match the system dark
              # base surface covers the gap. Use a single solid background rather than
              # the peach amber token that is visible behind the content area.
              # Dark: #1C1C1E (UIColor.systemBackground in dark, near-black).
              # Light: transparent (no override -- UITabBarController's default).
              ios_tabs_raw = LibC.getenv("TEST_RUNNER_HIG_APPEARANCE")
              ios_tabs_is_dark = !ios_tabs_raw.null? && String.new(ios_tabs_raw) == "dark"
              if ios_tabs_is_dark
                ios_tabview.background = UI::Color.new(r: 0.11, g: 0.11, b: 0.118, a: 1.0)
              end
              ios_tabview.accessibility_label = "Amber tab bar navigation"
              ios_tabview.as(UI::View)

              # iOS sidebars render as a tab bar (see above). The ios_tabview
              # is the return value for this slug on iPhone.

            when "split-views"
              # HIG: "A split view manages the presentation of multiple adjacent
              # panes of content." Distinct from sidebars (iter 41) — this slug
              # validates the FULL divided canvas: sidebar | list | detail.
              #
              # On iPhone (compact width) a NavigationSplitView collapses to a
              # NavigationStack showing one pane at a time. The iOS capture shows
              # the first pane (sidebar/navigation) with a "Compact width — single
              # pane" annotation label at the top, then the message list below as
              # the second pane content (simulated inline since iOS collapses to
              # stack navigation in compact width). This is HIG-correct: "Prefer
              # using a split view in a regular — not compact — environment."
              #
              # The three panes are rendered sequentially in a VStack (stacked
              # vertically on iPhone, as iOS would show them one at a time in a
              # real NavigationSplitView in compact). A visible Divider between
              # panes stands in for the column-width transition.

              # Compact annotation
              ios_sv_annotation = UI::Label.new("Compact width -- single-pane collapse")
              ios_sv_annotation.font = UI::Font.new(size: 12.0, weight: :regular)
              ios_sv_annotation.text_color = UI::Color.new(r: 0.55, g: 0.55, b: 0.55)
              ios_sv_annotation.accessibility_label = "Compact width single pane collapse annotation"

              # Pane 1: Sidebar navigation list
              ios_sv_mb_hdr = UI::Label.new("MAILBOXES")
              ios_sv_mb_hdr.font = UI::Font.new(size: 11.0, weight: :semibold)
              ios_sv_mb_hdr.text_color = UI::Color.new(r: 0.6, g: 0.6, b: 0.6)
              ios_sv_mb_hdr.accessibility_label = "Mailboxes section header"

              ios_sv_inbox_row = UI::HStack.new(spacing: 8.0)
              ios_sv_inbox_icon = UI::Image.new("envelope")
              ios_sv_inbox_icon.tint_color = UI::Color.new(r: 0.0, g: 0.478, b: 1.0)
              ios_sv_inbox_icon.accessibility_label = "Envelope icon"
              ios_sv_inbox_lbl = UI::Label.new("Inbox")
              ios_sv_inbox_lbl.font = UI::Font.new(size: 17.0, weight: :semibold)
              ios_sv_inbox_lbl.accessibility_label = "Inbox, selected"
              ios_sv_inbox_badge = UI::Label.new("12")
              ios_sv_inbox_badge.font = UI::Font.new(size: 14.0, weight: :semibold)
              ios_sv_inbox_badge.text_color = UI::Color.new(r: 0.6, g: 0.6, b: 0.6)
              ios_sv_inbox_badge.accessibility_label = "12 unread"
              ios_sv_inbox_sp = UI::Spacer.new
              ios_sv_inbox_row << ios_sv_inbox_icon
              ios_sv_inbox_row << ios_sv_inbox_lbl
              ios_sv_inbox_row << ios_sv_inbox_sp
              ios_sv_inbox_row << ios_sv_inbox_badge
              ios_sv_inbox_row.accessibility_label = "Inbox navigation row"

              ios_sv_flagged_row = UI::HStack.new(spacing: 8.0)
              ios_sv_flag_icon = UI::Image.new("flag")
              ios_sv_flag_icon.tint_color = UI::Color.new(r: 1.0, g: 0.584, b: 0.0)
              ios_sv_flag_icon.accessibility_label = "Flag icon"
              ios_sv_flagged_lbl = UI::Label.new("Flagged")
              ios_sv_flagged_lbl.font = UI::Font.new(size: 17.0, weight: :regular)
              ios_sv_flagged_lbl.accessibility_label = "Flagged"
              ios_sv_flagged_row << ios_sv_flag_icon
              ios_sv_flagged_row << ios_sv_flagged_lbl
              ios_sv_flagged_row.accessibility_label = "Flagged navigation row"

              ios_sv_sidebar_pane = UI::VStack.new(spacing: 0.0)
              ios_sv_sidebar_pane << ios_sv_mb_hdr
              ios_sv_sidebar_pane << ios_sv_inbox_row
              ios_sv_sidebar_pane << ios_sv_flagged_row
              ios_sv_sidebar_pane.accessibility_label = "Sidebar pane"

              # Pane separator
              ios_sv_sep_a = UI::Divider.new
              ios_sv_sep_a.accessibility_label = "Pane separator: sidebar to list"

              # Pane 2: Message list
              ios_sv_list_hdr = UI::Label.new("Inbox")
              ios_sv_list_hdr.font = UI::Font.new(size: 17.0, weight: :semibold)
              ios_sv_list_hdr.accessibility_label = "Inbox list header"

              ios_sv_list_pane = UI::VStack.new(spacing: 0.0)
              ios_sv_list_pane << ios_sv_list_hdr
              [
                {"Alice Martin", "Quarterly report", "Hi, please find the Q1 numbers..."},
                {"Bob Chen", "Re: Meeting notes", "Thanks for sending those. I reviewed..."},
                {"Carol Davis", "Weekend plans", "Are you free Saturday? We're thinking..."},
              ].each_with_index do |(sender, subject, preview), idx|
                if idx > 0
                  ios_sv_list_pane << UI::Divider.new
                end
                ios_msg_row = UI::VStack.new(spacing: 2.0)
                ios_msg_sender = UI::Label.new(sender)
                ios_msg_sender.font = UI::Font.new(size: 15.0, weight: :semibold)
                ios_msg_sender.accessibility_label = "Sender #{sender}"
                ios_msg_subject = UI::Label.new(subject)
                ios_msg_subject.font = UI::Font.new(size: 14.0, weight: :regular)
                ios_msg_subject.accessibility_label = "Subject #{subject}"
                ios_msg_preview = UI::Label.new(preview)
                ios_msg_preview.font = UI::Font.new(size: 12.0, weight: :regular)
                ios_msg_preview.text_color = UI::Color.new(r: 0.55, g: 0.55, b: 0.55)
                ios_msg_preview.accessibility_label = "Preview"
                ios_msg_row << ios_msg_sender
                ios_msg_row << ios_msg_subject
                ios_msg_row << ios_msg_preview
                ios_msg_row.accessibility_label = "Message from #{sender}"
                ios_sv_list_pane << ios_msg_row
              end
              ios_sv_list_pane.accessibility_label = "Message list pane"

              # Pane separator
              ios_sv_sep_b = UI::Divider.new
              ios_sv_sep_b.accessibility_label = "Pane separator: list to detail"

              # Pane 3: Detail
              ios_sv_detail_from = UI::Label.new("From: Alice Martin <alice@example.com>")
              ios_sv_detail_from.font = UI::Font.new(size: 13.0, weight: :regular)
              ios_sv_detail_from.accessibility_label = "From Alice Martin"
              ios_sv_detail_subject = UI::Label.new("Subject: Quarterly report")
              ios_sv_detail_subject.font = UI::Font.new(size: 13.0, weight: :semibold)
              ios_sv_detail_subject.accessibility_label = "Subject Quarterly report"
              ios_sv_detail_sep = UI::Divider.new
              ios_sv_detail_sep.accessibility_label = "Message header separator"
              ios_sv_detail_body = UI::Label.new("Hi, please find the Q1 numbers attached. Revenue was up 12% YoY and operating margin improved by 2.4 points.\n\n-- Alice")
              ios_sv_detail_body.font = UI::Font.new(size: 14.0, weight: :regular)
              ios_sv_detail_body.accessibility_label = "Message body"

              ios_sv_detail_pane = UI::VStack.new(spacing: 8.0)
              ios_sv_detail_pane << ios_sv_detail_from
              ios_sv_detail_pane << ios_sv_detail_subject
              ios_sv_detail_pane << ios_sv_detail_sep
              ios_sv_detail_pane << ios_sv_detail_body
              ios_sv_detail_pane.accessibility_label = "Message detail pane"

              # Outer container: all three panes stacked vertically on iPhone
              # (compact collapse). Each pane is separated by a Divider.
              ios_sv_outer = UI::VStack.new(spacing: 0.0)
              ios_sv_outer << ios_sv_annotation
              ios_sv_outer << ios_sv_sidebar_pane
              ios_sv_outer << ios_sv_sep_a
              ios_sv_outer << ios_sv_list_pane
              ios_sv_outer << ios_sv_sep_b
              ios_sv_outer << ios_sv_detail_pane
              ios_sv_outer.accessibility_label = "3-pane split view compact collapse"
              ios_sv_outer.as(UI::View)

            when "sheets"
              # Amber sheet: "Conjure Reminder" — Amber-voice scoped task sheet.
              # HIG: "A sheet helps people perform a scoped task that's closely
              # related to their current context." On iOS a sheet slides up from
              # the bottom with a grabber handle and resizes between detents.
              # Rendered inline (surface_style: :grouped_card) via
              # UIVisualEffectView + UIGlassEffect (iOS 26) / UIBlurEffect
              # (UIBlurEffectStyleSystemMaterial fallback). NOT via is_presented.
              # Fields use Amber copy per brand/amber.md.
              #
              # Architectural fix (June R2 review): sheet is now overlaid using
              # :bottom_sheet focal_position in the DashboardScene ZStack so it
              # sits atop the chrome rather than stacking below it and being
              # clipped. The sheet uses HStack form rows (label + field side by
              # side, one line each) so all content fits in the .medium detent
              # (~520pt). minimum_height=520 ensures the sheet fills to its detent.
              #
              # Action wiring: Conjure = primary CTA (Prominent, Amber gold fill);
              # Cancel = secondary (semibold, bordered/default style).
              # Grabber: 5pt tall, 36pt wide, secondary fill, centered at top.
              # Typography: title 17pt Headline; form labels 13pt regular.
              # HIG: "Include a grabber if the sheet can be resized."

              # Grabber handle — secondary fill pill, centered at sheet top.
              ios_sh_grabber_row = UI::HStack.new(spacing: 0.0)
              ios_sh_grabber_row << UI::Spacer.new.as(UI::View)
              ios_sh_grabber = UI::Label.new("          ")
              ios_sh_grabber.background = UI::Color.new(r: 0.55, g: 0.55, b: 0.55, a: 0.5)
              ios_sh_grabber.corner_radius = 2.5
              ios_sh_grabber.minimum_width = 36.0
              ios_sh_grabber.maximum_width = 36.0
              ios_sh_grabber.minimum_height = 5.0
              ios_sh_grabber.maximum_height = 5.0
              ios_sh_grabber.accessibility_label = "Sheet grabber"
              ios_sh_grabber_row << ios_sh_grabber.as(UI::View)
              ios_sh_grabber_row << UI::Spacer.new.as(UI::View)
              ios_sh_grabber_row.minimum_height = 20.0

              ios_sh_title = UI::Label.new("Conjure Reminder")
              ios_sh_title.font = UI::Font.new(size: 17.0, weight: :semibold)
              ios_sh_title.accessibility_label = "Sheet title: Conjure Reminder"

              ios_sh_divider = UI::Divider.new

              # Form rows: stacked label + field pairs.
              # Dark-appearance fix (June R3): text field background in dark mode is
              # lifted to 2nd-level material (~#2A1E0D with glass) so placeholder text
              # clears 4.5:1 against the field background.
              # TEST_RUNNER_HIG_APPEARANCE is read via LibC.getenv (runtime-safe).
              # UITextField uses UITextBorderStyleRoundedRect which provides a system
              # fill. We override the background color by setting view.background on
              # each field so apply_common_properties sets setBackgroundColor: on UITextField.
              ios_sh_is_dark = begin
                raw = LibC.getenv("TEST_RUNNER_HIG_APPEARANCE")
                !raw.null? && String.new(raw) == "dark"
              end
              # 2nd-level material dark fill: #2A1E0D (r=0.165 g=0.118 b=0.051, alpha=1).
              # In light mode: system default fill (UITextField with RoundedRect draws its
              # own system-appropriate fill, so we leave background unset in light).
              ios_sh_field_bg = ios_sh_is_dark ? UI::Color.new(r: 0.165, g: 0.118, b: 0.051, a: 1.0) : nil

              ios_sh_title_label = UI::Label.new("Title:")
              ios_sh_title_label.font = UI::Font.new(size: 13.0, weight: :regular)
              ios_sh_title_label.accessibility_label = "Title field label"
              ios_sh_title_field = UI::TextField.new("Morning pages title")
              ios_sh_title_field.accessibility_label = "Reminder title field"
              if fbg = ios_sh_field_bg
                ios_sh_title_field.background = fbg
              end

              ios_sh_date_label = UI::Label.new("When:")
              ios_sh_date_label.font = UI::Font.new(size: 13.0, weight: :regular)
              ios_sh_date_label.accessibility_label = "When field label"
              ios_sh_date_field = UI::TextField.new("e.g. Apr 15 \u00B7 7:00")
              ios_sh_date_field.accessibility_label = "Reminder date and time field"
              if fbg = ios_sh_field_bg
                ios_sh_date_field.background = fbg
              end

              ios_sh_priority_label = UI::Label.new("Weight:")
              ios_sh_priority_label.font = UI::Font.new(size: 13.0, weight: :regular)
              ios_sh_priority_label.accessibility_label = "Weight field label"
              ios_sh_priority_field = UI::TextField.new("None / Low / Medium / High")
              ios_sh_priority_field.accessibility_label = "Reminder priority field"
              if fbg = ios_sh_field_bg
                ios_sh_priority_field.background = fbg
              end

              ios_sh_form = UI::VStack.new(spacing: 8.0)
              ios_sh_form << ios_sh_title_label
              ios_sh_form << ios_sh_title_field
              ios_sh_form << ios_sh_date_label
              ios_sh_form << ios_sh_date_field
              ios_sh_form << ios_sh_priority_label
              ios_sh_form << ios_sh_priority_field

              ios_sh_divider2 = UI::Divider.new

              # Bottom action bar: Cancel (role: :cancel) + Conjure (Prominent).
              # HIG: "Always include a button that dismisses the sheet" — Cancel.
              # HIG: "Use the Prominent (filled) style for the most likely action."
              ios_sh_cancel = UI::Button.new("Cancel", role: :cancel)
              ios_sh_cancel.accessibility_label = "Cancel sheet"
              ios_sh_cancel.minimum_height = 44.0

              ios_sh_save = UI::Button.new("Conjure", role: :default, style: UI::ButtonStyle::Prominent)
              ios_sh_save.accessibility_label = "Conjure reminder"
              ios_sh_save.minimum_height = 44.0

              ios_sh_actions = UI::HStack.new(spacing: 12.0)
              ios_sh_actions << ios_sh_cancel
              ios_sh_actions << UI::Spacer.new
              ios_sh_actions << ios_sh_save
              ios_sh_actions.minimum_height = 44.0

              ios_sh_body = UI::VStack.new(spacing: 12.0)
              ios_sh_body << ios_sh_grabber_row
              ios_sh_body << ios_sh_title
              ios_sh_body << ios_sh_divider
              ios_sh_body << ios_sh_form
              ios_sh_body << ios_sh_divider2
              ios_sh_body << ios_sh_actions

              # Glass height: exact 400pt constraint (minimum == maximum) applied via
              # apply_common_properties -> objc_constrain_height at priority 999.
              # This is set on the GLASS (ios_sh, UIVisualEffectView), NOT on ios_sh_body
              # (which lives inside the glass's inner UIStackView and would create
              # unsatisfiable conflicts with the 4-edge-pinned inner stack constraints).
              #
              # Why 400pt:
              #   grabber_row(20) + title(22) + divider(1) + form(196) + divider2(1)
              #   + actions(44) + 5 gaps*12(60) = 344pt content.
              #   + inner stack layout margins top+bottom(32) = 376pt.
              #   + 24pt breathing room = 400pt.
              #
              # With an exact 400pt glass, the scene VStack's sizeThatFits returns:
              #   top_bar(60) + divider(1) + backdrop(60) + glass(400) = 521pt.
              # SwiftUI sizes UIViewRepresentable to 521pt, then UIStackView fill
              # distribution stretches the glass to exactly 400pt (already constrained).
              # Inner stack = 400 - 32 margins = 368pt; ios_sh_body fills 368pt with
              # UIStackView stretching ios_sh_form by 24pt. Cancel + Conjure fully visible.
              ios_sh = UI::Sheet.new(ios_sh_body.as(UI::View), surface_style: :grouped_card)
              ios_sh.minimum_height = 400.0
              ios_sh.maximum_height = 400.0
              ios_sh.as(UI::View)
            when "image-views"
              # HIG: "An image view displays a single image on a transparent or
              # opaque background." Six-variant gallery for iOS.
              #
              # UIStackView collapses UIView subclasses (Circle, Rectangle,
              # RoundedRectangle) that have no intrinsicContentSize. On iOS the
              # shape variants use UI::Label with background + corner_radius
              # (wired via apply_common_properties) to produce visible filled
              # regions whose height is driven by text intrinsic size.
              # The macOS arm uses native NSView shape classes; both arms
              # exercise the same HIG use-cases. See gaps.md iteration 29.
              gallery = UI::VStack.new(spacing: 12.0)

              # 1. SF Symbol: star.fill via UIImageView with tint
              # UIImage imageNamed: returns nil without asset catalog;
              # a blue-tinted label stands in for the symbol surface.
              sym_hdr = UI::Label.new("1. SF Symbol (star.fill, system blue tint)")
              sym_hdr.font = UI::Font.new(size: 13.0, weight: :semibold)
              gallery << sym_hdr
              sym_tile = UI::Label.new("\nstar.fill  60pt  tint: system blue\n")
              sym_tile.font = UI::Font.new(size: 14.0, weight: :regular)
              sym_tile.text_color_role = nil
              sym_tile.text_color = UI::Color.new(r: 1.0, g: 1.0, b: 1.0)
              sym_tile.background = UI::Color.new(r: 0.0, g: 0.478, b: 1.0)
              sym_tile.corner_radius = 8.0
              gallery << sym_tile

              # 2. Square photo thumbnail: gray fill + border
              thumb_hdr = UI::Label.new("2. Square thumbnail (gray, bordered)")
              thumb_hdr.font = UI::Font.new(size: 13.0, weight: :semibold)
              gallery << thumb_hdr
              thumb_tile = UI::Label.new("\n\n\nPhoto placeholder  120x120\n\n\n")
              thumb_tile.font = UI::Font.new(size: 13.0, weight: :regular)
              thumb_tile.text_color_role = nil
              thumb_tile.text_color = UI::Color.new(r: 0.3, g: 0.3, b: 0.3)
              thumb_tile.background = UI::Color.new(r: 0.82, g: 0.82, b: 0.84)
              thumb_tile.border_width = 1.0
              thumb_tile.border_color = UI::Color.new(r: 0.6, g: 0.6, b: 0.62)
              gallery << thumb_tile

              # 3. Circular avatar: tan fill, white border, corner_radius simulates clip
              avatar_hdr = UI::Label.new("3. Circular avatar (tan fill, clipped)")
              avatar_hdr.font = UI::Font.new(size: 13.0, weight: :semibold)
              gallery << avatar_hdr
              avatar_tile = UI::Label.new("\n  Avatar (64pt diameter)  \n")
              avatar_tile.font = UI::Font.new(size: 14.0, weight: :regular)
              avatar_tile.text_color_role = nil
              avatar_tile.text_color = UI::Color.new(r: 1.0, g: 1.0, b: 1.0)
              avatar_tile.background = UI::Color.new(r: 0.69, g: 0.56, b: 0.49)
              avatar_tile.border_width = 2.0
              avatar_tile.border_color = UI::Color.new(r: 1.0, g: 1.0, b: 1.0)
              avatar_tile.corner_radius = 28.0
              avatar_tile.clip_to_bounds = true
              gallery << avatar_tile

              # 4. Rounded card: slate blue, 12pt radius
              card_hdr = UI::Label.new("4. Rounded card (12pt radius)")
              card_hdr.font = UI::Font.new(size: 13.0, weight: :semibold)
              gallery << card_hdr
              card_tile = UI::Label.new("\n\nThumbnail  120x120  12pt radius\n\n")
              card_tile.font = UI::Font.new(size: 14.0, weight: :regular)
              card_tile.text_color_role = nil
              card_tile.text_color = UI::Color.new(r: 1.0, g: 1.0, b: 1.0)
              card_tile.background = UI::Color.new(r: 0.27, g: 0.40, b: 0.60)
              card_tile.corner_radius = 12.0
              card_tile.clip_to_bounds = true
              gallery << card_tile

              # 5. Loading state: UIActivityIndicatorView + label
              loading_hdr = UI::Label.new("5. Loading state")
              loading_hdr.font = UI::Font.new(size: 13.0, weight: :semibold)
              gallery << loading_hdr
              spinner_row = UI::HStack.new(spacing: 8.0)
              spinner = UI::ActivityIndicator.new(true, :medium)
              spinner_row << spinner
              spinner_row << UI::Label.new("Loading image...")
              gallery << spinner_row

              # 6. Error/placeholder state: broken-image pattern
              err_hdr = UI::Label.new("6. Error / placeholder state")
              err_hdr.font = UI::Font.new(size: 13.0, weight: :semibold)
              gallery << err_hdr
              err_tile = UI::Label.new("\n  [broken image]  Failed to load\n")
              err_tile.font = UI::Font.new(size: 13.0, weight: :regular)
              err_tile.text_color_role = nil
              err_tile.text_color = UI::Color.new(r: 0.4, g: 0.4, b: 0.4)
              err_tile.background = UI::Color.new(r: 0.90, g: 0.90, b: 0.92)
              err_tile.border_width = 1.0
              err_tile.border_color = UI::Color.new(r: 0.75, g: 0.75, b: 0.77)
              err_tile.corner_radius = 8.0
              gallery << err_tile

              gallery.as(UI::View)
            when "tab-bars"
              # HIG: "A tab bar lets people navigate between top-level sections of your app."
              # HIG tab-bars Platform considerations (iOS): "A tab bar floats above content at
              # the bottom of the screen. Its items rest on a Liquid Glass background that allows
              # content beneath to peek through."
              # Showcase: 5-tab bar -- house/Home, magnifyingglass/Search (selected, index 1),
              # heart/Favorites, bell/Activity, person/Profile.
              # UIGlassEffect (iOS 26) preferred; falls back to UIBlurEffectStyleSystemChromeMaterial.
              # HIG: "Consider using SF Symbols to provide familiar, scalable tab bar icons."
              # HIG: "Include tab labels to help with navigation."
              # HIG: "Use the appropriate number of tabs required to help people navigate your app."

              ios_home_content = UI::VStack.new(spacing: 8.0)
              ios_home_lbl = UI::Label.new("Home")
              ios_home_lbl.font = UI::Font.new(size: 15.0, weight: :semibold)
              ios_home_lbl.accessibility_label = "Home section content"
              ios_home_content << ios_home_lbl

              ios_search_content = UI::VStack.new(spacing: 8.0)
              ios_search_lbl = UI::Label.new("Search")
              ios_search_lbl.font = UI::Font.new(size: 15.0, weight: :semibold)
              ios_search_lbl.accessibility_label = "Search section content"
              ios_search_desc = UI::Label.new("Tab bars -- UIGlassEffect / UIVisualEffectView")
              ios_search_desc.font = UI::Font.new(size: 12.0, weight: :regular)
              ios_search_desc.text_color_role = UI::LabelRole::Secondary
              ios_search_desc.accessibility_label = "Tab bar description"
              ios_search_content << ios_search_lbl
              ios_search_content << ios_search_desc

              ios_tabs = [
                UI::TabView::Tab.new(label: "Home",       icon: "house",           content: ios_home_content.as(UI::View)),
                UI::TabView::Tab.new(label: "Search",     icon: "magnifyingglass", content: ios_search_content.as(UI::View)),
                UI::TabView::Tab.new(label: "Favorites",  icon: "heart",           content: UI::Label.new("Favorites").as(UI::View)),
                UI::TabView::Tab.new(label: "Activity",   icon: "bell",            content: UI::Label.new("Activity").as(UI::View)),
                UI::TabView::Tab.new(label: "Profile",    icon: "person",          content: UI::Label.new("Profile").as(UI::View)),
              ]

              ios_tab_view = UI::TabView.new(ios_tabs, 1)
              ios_tab_view.glass_bar = true
              ios_tab_view.accessibility_label = "Tab bar navigation"

              ios_tab_view.as(UI::View)
            when "tab-views"
              # HIG tab-views: macOS-primary pattern (NSTabView). On iOS the HIG
              # explicitly states "Not supported in iOS, iPadOS" -- the platform
              # recommendation is a segmented control. For validation purposes we
              # render the same UITabBar-style bottom bar (bar_position: :bottom)
              # and note in the component doc that iOS apps should use SegmentedControl
              # instead of NSTabView-style top tabs.
              # The iOS showcase re-uses the UIGlassEffect glass surface from tab-bars.
              # HIG: "For similar functionality [on iOS], consider using a segmented
              # control instead." -- tab-views Platform considerations, iOS.

              ios_general_content = UI::VStack.new(spacing: 8.0)
              ios_general_lbl = UI::Label.new("General")
              ios_general_lbl.font = UI::Font.new(size: 15.0, weight: :semibold)
              ios_general_lbl.accessibility_label = "General settings heading"
              ios_general_note = UI::Label.new("Tab views are macOS-only (NSTabView). iOS: use SegmentedControl.")
              ios_general_note.font = UI::Font.new(size: 12.0, weight: :regular)
              ios_general_note.text_color_role = UI::LabelRole::Secondary
              ios_general_note.accessibility_label = "Platform note"
              ios_general_content << ios_general_lbl
              ios_general_content << ios_general_note

              ios_tv_tabs = [
                UI::TabView::Tab.new(label: "General",  content: ios_general_content.as(UI::View)),
                UI::TabView::Tab.new(label: "Advanced", content: UI::Label.new("Advanced").as(UI::View)),
                UI::TabView::Tab.new(label: "Access.",  content: UI::Label.new("Accessibility").as(UI::View)),
                UI::TabView::Tab.new(label: "Updates",  content: UI::Label.new("Updates").as(UI::View)),
              ]

              ios_tv = UI::TabView.new(ios_tv_tabs, 0)
              ios_tv.bar_position = :bottom
              ios_tv.glass_bar = true
              ios_tv.accessibility_label = "Tab view navigation (iOS fallback)"

              ios_tv.as(UI::View)
            when "charts"
              # Amber charts: "Focus minutes this week" bar chart, 7 days.
              # Bar fill: Amber plum (#5B3A94 -> r:0.357 g:0.227 b:0.58), NOT systemBlue.
              # iOS clipping fix: chart is wrapped in a ScrollView so it gets an
              # explicit intrinsicContentSize in compact width (UIKit requires this
              # for Charts to not clip at zero-height in a UIStackView).
              # HIG: "In a compact environment, maximize the width of the plot area."
              ios_plum = UI::Color.new(r: 0.357, g: 0.227, b: 0.58)
              ios_chart = UI::ChartView.new
              ios_chart.chart_type = :bar
              ios_chart.title = "Focus minutes this week"
              ios_chart.data_points = [
                UI::ChartDataPoint.new(label: "Mon", value: 94.0,  color: ios_plum),
                UI::ChartDataPoint.new(label: "Tue", value: 120.0, color: ios_plum),
                UI::ChartDataPoint.new(label: "Wed", value: 45.0,  color: ios_plum),
                UI::ChartDataPoint.new(label: "Thu", value: 138.0, color: ios_plum),
                UI::ChartDataPoint.new(label: "Fri", value: 82.0,  color: ios_plum),
                UI::ChartDataPoint.new(label: "Sat", value: 157.0, color: ios_plum),
                UI::ChartDataPoint.new(label: "Sun", value: 63.0,  color: ios_plum),
              ]
              ios_chart.show_grid = true
              ios_chart.accessibility_label = "Focus minutes this week bar chart, Mon through Sun"
              ios_chart_scroll = UI::ScrollView.new(ios_chart.as(UI::View))
              ios_chart_scroll.accessibility_label = "Focus minutes chart scroll container"
              ios_chart_scroll.as(UI::View)
            when "color-wells"
              # HIG Color wells: swatch button showing current color.
              # HIG Best practices: "Consider the system-provided color picker for a
              # familiar experience."
              # iOS renders UIView with background color (UIColorWell placeholder).
              ios_outer = UI::VStack.new(spacing: 16.0)

              # Row 1: labeled red color well.
              ios_row1 = UI::HStack.new(spacing: 12.0)
              ios_lbl1 = UI::Label.new("Stroke color")
              ios_lbl1.accessibility_label = "Stroke color label"
              ios_well1 = UI::ColorPicker.new
              ios_well1.selected_color = UI::Color.new(r: 1.0, g: 0.0, b: 0.0)
              ios_well1.label = "Stroke color"
              ios_well1.accessibility_label = "Stroke color well, red"
              ios_row1 << ios_lbl1
              ios_row1 << ios_well1

              # Row 2: custom teal color well.
              ios_row2 = UI::HStack.new(spacing: 12.0)
              ios_lbl2 = UI::Label.new("Fill color")
              ios_lbl2.accessibility_label = "Fill color label"
              ios_well2 = UI::ColorPicker.new
              ios_well2.selected_color = UI::Color.new(r: 0.0, g: 0.537, b: 0.482)
              ios_well2.label = "Fill color"
              ios_well2.accessibility_label = "Fill color well, teal"
              ios_row2 << ios_lbl2
              ios_row2 << ios_well2

              # Row 3: "Pick a color..." label + orange color well.
              ios_row3 = UI::HStack.new(spacing: 12.0)
              ios_lbl3 = UI::Label.new("Pick a color...")
              ios_lbl3.accessibility_label = "Pick a color prompt"
              ios_well3 = UI::ColorPicker.new
              ios_well3.selected_color = UI::Color.new(r: 1.0, g: 0.584, b: 0.0)
              ios_well3.label = "Pick a color"
              ios_well3.accessibility_label = "Pick a color well, orange"
              ios_row3 << ios_lbl3
              ios_row3 << ios_well3

              ios_outer << ios_row1
              ios_outer << ios_row2
              ios_outer << ios_row3
              ios_outer.as(UI::View)
            when "web-views"
              # HIG Web views: embeds rich HTML/URL content inside an app.
              # iOS: WKWebView (WebKit); placeholder UIView with border for capture.
              ios_wv_outer = UI::VStack.new(spacing: 12.0)

              ios_wv_label = UI::Label.new("Embedded web content")
              ios_wv_label.accessibility_label = "Embedded web content heading"

              ios_wv_desc = UI::Label.new("example.com — WebKit renders HTML inside your app.")
              ios_wv_desc.accessibility_label = "Web view description"

              ios_wv = UI::WebViewComponent.new(url: "https://example.com")
              ios_wv.title = "example.com"
              ios_wv.allows_navigation = true
              ios_wv.accessibility_label = "Web view: example.com"

              ios_wv_outer << ios_wv_label
              ios_wv_outer << ios_wv_desc
              ios_wv_outer << ios_wv
              ios_wv_outer.as(UI::View)
            when "page-controls"
              # HIG: "A page control displays a row of indicator images, each of
              # which represents a page in a flat list." — Page controls, abstract.
              # UIPageControl on iOS 26. 5 pages, current = 2 (third dot filled).
              ios_pc_outer = UI::VStack.new(spacing: 16.0)

              ios_pc_label1 = UI::Label.new("Default (system, page 3 of 5):")
              ios_pc_label1.accessibility_label = "Default page control label"
              ios_pc_outer << ios_pc_label1

              ios_pc = UI::PageControl.new(total: 5, current: 2)
              ios_pc.accessibility_label = "Page 3 of 5"
              ios_pc_outer << ios_pc

              ios_pc_label2 = UI::Label.new("Tinted (brand orange, page 1 of 5):")
              ios_pc_label2.accessibility_label = "Tinted page control label"
              ios_pc_outer << ios_pc_label2

              ios_pc_tinted = UI::PageControl.new(total: 5, current: 0)
              ios_pc_tinted.tint_color = UI::Color.new(r: 1.0, g: 0.58, b: 0.0)
              ios_pc_tinted.accessibility_label = "Page 1 of 5, orange tint"
              ios_pc_outer << ios_pc_tinted

              ios_pc_outer.as(UI::View)
            when "combo-boxes"
              # HIG Platform considerations: "Not supported in iOS, iPadOS,
              # tvOS, visionOS, or watchOS."
              # UIKit renderer falls back to a UITextField with a trailing
              # chevron.down SF Symbol button — the standard iOS pattern for
              # a text field with an attached picker/menu.
              ios_cb_outer = UI::VStack.new(spacing: 12.0)

              ios_cb_label = UI::Label.new("Country:")
              ios_cb_label.accessibility_label = "Country label"
              ios_cb_outer << ios_cb_label

              ios_cb = UI::ComboBox.new(
                value: "United States",
                options: ["United States", "Canada", "Mexico", "United Kingdom", "Germany"],
                placeholder: "Select or type\u2026",
                width: 280.0
              )
              ios_cb.accessibility_label = "Country combo box"
              ios_cb_outer << ios_cb

              ios_cb_label2 = UI::Label.new("Browser:")
              ios_cb_label2.accessibility_label = "Browser label"
              ios_cb_outer << ios_cb_label2

              ios_cb2 = UI::ComboBox.new(
                value: "",
                options: ["Safari", "Chrome", "Firefox", "Edge"],
                placeholder: "Select or type\u2026",
                width: 280.0
              )
              ios_cb2.accessibility_label = "Browser combo box"
              ios_cb_outer << ios_cb2

              ios_cb_outer.as(UI::View)
            when "rating-indicators"
              # HIG Platform considerations: "Not supported in iOS, iPadOS,
              # tvOS, visionOS, or watchOS." — NSLevelIndicator is macOS-only.
              # UIKit renderer synthesises a horizontal UIStackView of
              # UIImageViews carrying SF Symbol names "star.fill" / "star".
              ios_ri_outer = UI::VStack.new(spacing: 16.0)

              ios_ri_lbl1 = UI::Label.new("5 of 5 stars (full):")
              ios_ri_lbl1.accessibility_label = "5 of 5 stars label"
              ios_ri_outer << ios_ri_lbl1
              ios_ri_full = UI::RatingIndicator.new(value: 5.0, max: 5)
              ios_ri_full.accessibility_label = "5 out of 5 stars"
              ios_ri_outer << ios_ri_full

              ios_ri_lbl2 = UI::Label.new("3 of 5 stars (partial):")
              ios_ri_lbl2.accessibility_label = "3 of 5 stars label"
              ios_ri_outer << ios_ri_lbl2
              ios_ri_partial = UI::RatingIndicator.new(value: 3.0, max: 5)
              ios_ri_partial.accessibility_label = "3 out of 5 stars"
              ios_ri_outer << ios_ri_partial

              ios_ri_lbl3 = UI::Label.new("2 of 5 stars:")
              ios_ri_lbl3.accessibility_label = "2 of 5 stars label"
              ios_ri_outer << ios_ri_lbl3
              ios_ri_two = UI::RatingIndicator.new(value: 2.0, max: 5)
              ios_ri_two.accessibility_label = "2 out of 5 stars"
              ios_ri_outer << ios_ri_two

              ios_ri_lbl4 = UI::Label.new("3 of 5 stars (blue tint):")
              ios_ri_lbl4.accessibility_label = "3 of 5 stars blue tint label"
              ios_ri_outer << ios_ri_lbl4
              ios_ri_tint = UI::RatingIndicator.new(
                value: 3.0,
                max: 5,
                tint_color: UI::Color.new(r: 0.0, g: 0.48, b: 1.0)
              )
              ios_ri_tint.accessibility_label = "3 out of 5 stars blue tint"
              ios_ri_outer << ios_ri_tint

              ios_ri_outer.as(UI::View)
            else                            UI::Label.new("Unknown slug: #{slug}").as(UI::View)
            end
    # For scene-wrapped slugs, return just the focal component (child) so the
    # scene composer gets a clean component without a wrapper VStack.
    # For non-scene slugs, tag the vstack with the accessibility root label so
    # the iOS XCUITest harness can confirm the app launched and rendered content.
    # (The old "HIG: <slug>" debug label that served as the root was removed per
    # Issue B; the test_id + accessibility_label on the vstack replaces it.)
    if scene_for_slug(slug)
      child
    else
      vstack << child
      vstack.accessibility_label = "hig-component-root"
      vstack.test_id = "hig-component-root"
      vstack.as(UI::View)
    end
  end
end

# ---------------------------------------------------------------------------
# C ABI exports -- callable from Swift via CrystalHIGHost-Bridging-Header.h
# ---------------------------------------------------------------------------

fun crystal_init : Void
  CrystalHIGHost::Bridge.initialize_runtime
end

# Build and render one component by slug. Returns a raw UIView* that Swift
# takes ownership of via Unmanaged.fromOpaque(..).takeRetainedValue().
#
# NOTE on pointer ownership: the asset_pipeline UIKit renderer allocates
# its native objects with "owned" semantics (+1 retain). The produced
# NativeHandle.ptr is that +1 pointer. We do NOT call release! here --
# ownership transfers to Swift. We keep @@last_native as a weak
# "don't-GC-the-tree-before-Swift-reads-it" anchor; Swift's takeRetainedValue
# bumps the retain count enough that Crystal GC tearing down NativeView
# later is safe (ObjC retain keeps UIKit object alive regardless).
fun crystal_render_slug(slug_ptr : LibC::Char*) : Void*
  CrystalHIGHost::Bridge.initialize_runtime
  slug = String.new(slug_ptr)
  view = CrystalHIGHost::Bridge.build_component(slug)
  renderer = UI::UIKit::Renderer.new
  native = renderer.render(view)
  CrystalHIGHost::Bridge.last_native = native

  # UI::NativeView exposes its native pointer via `handle.ptr!` (NativeHandle#ptr!).
  # See src/ui/native/native_handle.cr -- the documented retained-pointer API.
  native.handle.ptr!
end

{% end %}
