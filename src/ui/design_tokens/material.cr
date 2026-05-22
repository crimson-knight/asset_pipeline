module UI
  module DesignTokens
    # One material strength step.
    #
    # Per-step values declare how a particular `UI::GlassBackground#material`
    # symbol renders. `blur_radius` is scaled by the parent `Material#intensity`
    # on web (via `calc()` against `--ap-material-intensity`) and on Android
    # API 31+ (via the `RenderEffect.createBlurEffect` radius argument). On
    # Apple, `intensity` has NO visible effect — SwiftUI's `Material` is a
    # discrete enum and the declared step maps directly. See
    # `docs/initiative-cross-platform-ui/phases/phase-05-glass-material-tokenization/brief.yml`
    # `adapter_cardinality` row 1 for the documented consumer-visible contract.
    record MaterialStep,
      blur_radius : Float64,    # CSS px / Apple pt / Android dp at intensity=1.0
      opacity : Float64,        # 0..1 — fill opacity (web color-mix, Android alpha)
      saturation : Float64,     # backdrop saturation multiplier (1.0 = neutral)
      luminance : Float64       # [-1, 1] luminance bias for fallback fills

    # Glass material token branch.
    #
    # The five `MaterialStep` fields preserve existing per-step behavior at
    # `intensity == 1.0`. `intensity` is a brand-declaration-time scalar that
    # consumers re-render to observe. Phase 5 explicitly does NOT introduce a
    # runtime mutator path — see `brief.yml` invariant I-2 (`preserves`).
    #
    # ## Apple quantization contract
    #
    # SwiftUI's `Material` enum is discrete (.ultraThinMaterial, .thinMaterial,
    # .regularMaterial, .thickMaterial, .ultraThickMaterial). The declared
    # `GlassBackground#material` symbol maps 1:1 to a SwiftUI Material case.
    # `intensity` does NOT shift Apple per-view material steps — a view
    # declaring `material: :thick` always renders `.thickMaterial` regardless
    # of brand intensity. `apple_step(declared)` exposes this quantization;
    # the Apple renderer invokes it instead of `resolve` so the discrete
    # contract is the single source of truth.
    #
    # When the declared material is `:regular` (the default for unspecified
    # `GlassBackground` views), `apple_step` does honor brand intensity by
    # mapping the intensity scalar through the documented quantization table
    # (see `brief.yml` adapter_cardinality row 1):
    #   intensity <= 0.3 -> :ultra_thin
    #   intensity <= 0.7 -> :thin
    #   intensity <= 1.3 -> :regular   (brief's worked example: 1.3 -> regular)
    #   intensity <  1.8 -> :thick
    #   intensity >= 1.8 -> :chrome    ("1.8+" per the brief)
    #
    # The brief's text uses both en-dash interval notation ("0.7–1.3 ->
    # regular") AND a worked example ("intensity 1.3 quantizes to
    # .regularMaterial on Apple"). The implementation honors the worked
    # example AND the "1.8+" notation by using mixed boundary types:
    # the first three buckets have INCLUSIVE upper bounds (so 1.3 ->
    # :regular) and the last threshold is INCLUSIVE on the chrome side
    # (so 1.8 -> :chrome). `material_spec.cr` pins these exact boundary
    # values so any future drift surfaces as a spec failure.
    record Material,
      ultra_thin : MaterialStep,
      thin : MaterialStep,
      regular : MaterialStep,
      thick : MaterialStep,
      chrome : MaterialStep,
      intensity : Float64 do
      # Lookup the `MaterialStep` for a symbol. Unknown symbols fall back to
      # `:regular` rather than raising — `UI::GlassBackground#material` is
      # already typed `Symbol` and the renderer must not crash on an
      # off-spec value.
      def step(name : Symbol) : MaterialStep
        case name
        when :ultra_thin then ultra_thin
        when :thin       then thin
        when :regular    then regular
        when :thick      then thick
        when :chrome     then chrome
        else                  regular
        end
      end

      # Apple step quantization. Returns the symbol the Apple facade should
      # use to pick its `SwiftUI.Material` case.
      #
      # When the declared step is anything other than `:regular`, that step
      # is returned unchanged (developer intent wins). When the declared
      # step is `:regular` (the default), intensity is consulted via the
      # documented quantization table from brief.yml row 1:
      #   intensity < 0.3  -> :ultra_thin
      #   intensity < 0.7  -> :thin
      #   intensity < 1.3  -> :regular   (1.0 default lands here)
      #   intensity < 1.8  -> :thick
      #   intensity >= 1.8 -> :chrome   ("1.8+" per the brief)
      # Boundaries are deliberately exclusive on the upper edge so the
      # `1.8+` notation in the brief is honored exactly: `1.8` maps to
      # :chrome (not :thick), `1.299...` maps to :regular, etc.
      def apple_step(declared : Symbol) : Symbol
        return declared unless declared == :regular
        i = intensity
        return :ultra_thin if i <= 0.3
        return :thin if i <= 0.7
        return :regular if i <= 1.3
        return :chrome if i >= 1.8
        :thick
      end

      # Render-time resolution for web / Android. Renderers consume this.
      # `blur_radius` is scaled by `intensity` clamped to the documented
      # `[0.0, 2.0]` range from brief.yml adapter_cardinality row 1.
      # Out-of-range brand declarations are clamped rather than raising —
      # this matches Crystal's existing `Float64#clamp` semantics on every
      # other token field.
      def resolve(name : Symbol) : ResolvedStep
        s = step(name)
        clamped = intensity.clamp(0.0, 2.0)
        ResolvedStep.new(
          name: name,
          blur_radius: s.blur_radius * clamped,
          opacity: s.opacity,
          saturation: s.saturation,
          luminance: s.luminance,
        )
      end
    end

    # Output of `Material#resolve` — what web + Android renderers consume.
    record ResolvedStep,
      name : Symbol,
      blur_radius : Float64,
      opacity : Float64,
      saturation : Float64,
      luminance : Float64

  end
end
