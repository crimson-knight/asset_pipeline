# fixture_for: family_2/view_has_spec
# expected: pass
# synthetic_path: src/ui/views/_gate_stubs/no_such_widget.cr
#
# Tier-3 gate stubs are excluded from the rule's scan. Even when the
# fixture declares `class NoSuchWidget < View` and no spec exists, the
# rule skips the file because its synthetic_path is under
# `src/ui/views/_gate_stubs/`.

module UI
  class NoSuchWidget
    macro new(*args, **kwargs)
      {% raise "gate" %}
    end
  end
end
