require "./component_css_registry"

# Component CSS for the Phase 2 container-query showcase components: Card,
# Form, and NavigationSplitView. These rules opt the canonical surface
# classes (`.am-card`, `.am-form`, `.am-split-view`) into being container-
# query roots and ship the layout-switch declarations as `@container <name>`
# blocks so the components reflow against *their* rendering width rather
# than the viewport.
#
# Loading this file is enough to register the CSS via the global
# `ComponentCSSRegistry`; the Generator picks the entries up in its
# `@layer components` pass.
module Components
  module CSS
    module ContainerQueryComponents
      CARD_CSS = <<-CSS
      .am-card {
        container-type: inline-size;
        container-name: card;
      }

      @container card (min-width: 480px) {
        .am-card[data-layout="auto"] .am-card__layout {
          flex-direction: row;
          gap: var(--ap-space-4, 1rem);
        }
        .am-card[data-layout="auto"] .am-card__media {
          flex: 0 0 40%;
        }
        .am-card[data-layout="auto"] .am-card__body {
          flex: 1 1 auto;
        }
      }

      @container card (min-width: 720px) {
        .am-card[data-layout="auto"] .am-card__layout {
          gap: var(--ap-space-6, 1.5rem);
        }
      }
      CSS

      FORM_CSS = <<-CSS
      .am-form {
        container-type: inline-size;
        container-name: form;
      }

      @container form (max-width: 360px) {
        .am-form[data-layout="auto"] .am-form-field {
          flex-direction: column;
          align-items: stretch;
        }
        .am-form[data-layout="auto"] .am-form-field > label {
          min-width: 0;
        }
      }

      @container form (min-width: 480px) {
        .am-form[data-layout="auto"] .am-form-field {
          flex-direction: row;
          align-items: center;
        }
      }
      CSS

      SPLIT_VIEW_CSS = <<-CSS
      .am-split-view {
        container-type: inline-size;
        container-name: split-view;
      }

      @container split-view (max-width: 767px) {
        .am-split-view[data-layout="auto"] {
          flex-direction: column;
        }
        .am-split-view[data-layout="auto"] > .am-split-view__sidebar {
          width: 100%;
          border-right: 0;
          border-bottom: 1px solid var(--ap-color-border-subtle);
        }
      }

      @container split-view (min-width: 768px) {
        .am-split-view[data-layout="auto"] {
          flex-direction: row;
        }
      }
      CSS

      ComponentCSSRegistry.instance.register("UI::Card", CARD_CSS)
      ComponentCSSRegistry.instance.register("UI::Form", FORM_CSS)
      ComponentCSSRegistry.instance.register("UI::NavigationSplitView", SPLIT_VIEW_CSS)
    end
  end
end
