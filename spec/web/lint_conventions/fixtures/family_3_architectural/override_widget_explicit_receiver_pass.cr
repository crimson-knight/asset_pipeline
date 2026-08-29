# fixture_for: family_3/override_widget_subclass
# expected: pass
# synthetic_path: src/apps/explicit_receiver_app.cr
#
# False-positive guard #2 — explicit-receiver parens form on
# `UI::App.override_widget(...)` (NOT the bare-form macro). Must pass.

class MyExplicitReceiverApp < UI::App
end

MyExplicitReceiverApp.override_widget(:swipe_actions, AcmeFancySwipeRow)
