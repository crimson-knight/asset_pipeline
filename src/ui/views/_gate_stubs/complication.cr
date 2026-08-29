# Compile-time stub for `UI::Complication` on non-watchOS targets.
#
# Lives outside an `{% if flag?(...) %}` macro so the `{% raise %}` inside
# `macro new` only fires at construction sites, not at class-definition time.
# This file must only be required when `flag?(:watchos)` is FALSE — see
# `src/ui/views/complication.cr` for the gate.

module UI
  # watchOS complication (watchOS only).
  class Complication
    macro new(*args, **kwargs)
      {% raise <<-MSG
        UI::Complication is watchOS-only (Tier 3). A WidgetKit complication has
        no honest cross-platform analog — it is a watch-face / smart-stack
        surface. This build does not have -Dwatchos.

        Pick one:

        1. Build with -Dwatchos:
             crystal build my_app.cr -Dwatchos

        2. Use the explicit cross-platform companion instead:
             UI::ComplicationWithWebFallback.new(kind: :next_todo, content: ...)
           which renders a real watchOS complication on -Dwatchos and a
           credible card-style preview of the content on every other target.

        3. Guard the usage at the call site:
             {% if flag?(:watchos) %}
               c = UI::Complication.new(kind: :next_todo, content: ...)
               # ...
             {% else %}
               # alternate UI for this platform
             {% end %}

        See docs/initiative-cross-platform-ui/tier-matrix.md for the tier
        classification and docs/initiative-cross-platform-ui/phases/phase-12-watchos.md
        for the watchOS target plan.
        MSG
      %}
    end
  end
end
