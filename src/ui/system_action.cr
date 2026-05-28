# Phase 10D-final — UI::SystemAction dispatcher entry point.
#
# `UI::SystemAction.perform(name, **args)` invokes an OS-level binding
# registered in `UI::SystemAction::Registry`. This is the renamed Class C
# dispatch entry — formerly `UI::Intent.dispatch`.
#
# Reads aloud: "perform the system action copy-to-clipboard with these args."
#
# "System" makes it unambiguous that this calls into the operating system,
# not a controller action.
#
# # Return contract
#
# Returns a `UI::SystemAction::Result`:
#
#   * `Result.success`           — the platform lambda completed without raising.
#   * `Result.unsupported(why)`  — no binding registered, OR the binding does
#                                  not cover the current platform, OR the
#                                  binding's `api_capability_check` returned false.
#   * `Result.failed(reason)`    — the platform lambda raised; `reason` is the
#                                  exception message.
#
# Dispatch is fire-and-forget by contract — the result is informational.
# Callers that need result data wire it through a callback inside `args`.
#
# # args shape
#
# `args` is `Hash(Symbol, String)` — the lowest-common-denominator shape that
# crosses JNI / objc bridge boundaries safely. Native bindings parse the
# string keys inside the platform lambda. Convenience overload accepts
# kwargs and packs them.

require "./system_action/result"
require "./system_action/platform_binding"
require "./system_action/registry"

module UI
  module SystemAction
    # Convenience overload — accepts kwargs and packs them into the
    # `Hash(Symbol, String)` form the substrate uses. Keyword values
    # may be any type that supports `to_s`; the conversion happens
    # here so bindings can rely on string args downstream.
    #
    # Call-sites can spell:
    #
    #     UI::SystemAction.perform(:hello_world_alert, message: "hi")
    #
    # in place of the more verbose Hash-literal form.
    def self.perform(name : Symbol, **kwargs) : Result
      args = {} of Symbol => String
      kwargs.each do |k, v|
        args[k] = v.to_s
      end
      perform(name, args)
    end

    def self.perform(
      name : Symbol,
      args : Hash(Symbol, String) = {} of Symbol => String,
    ) : Result
      binding = UI::SystemAction::Registry.binding_for(name)
      unless binding
        return Result.unsupported(
          "No system action binding registered for #{name.inspect}. " \
          "Bindings are installed by `UI::SystemAction::Bootstrap` at framework " \
          "load — if you expected this action to be wired, confirm the bootstrap " \
          "file is required and the binding hasn't been gated out by a missing " \
          "compile-time flag."
        )
      end

      platform = UI::Environment.platform
      unless binding.supports?(platform)
        return Result.unsupported(
          "System action #{name.inspect} has a binding registered, but the binding " \
          "does not cover platform #{platform.inspect} (or its api_capability_check " \
          "returned false). Either extend the binding's `platforms` map to include " \
          "#{platform.inspect}, or fall back to a platform-appropriate UI " \
          "(e.g. degrade to a copy-link when share isn't available)."
        )
      end

      proc = binding.platform_proc(platform)
      unless proc
        # Defensive — supports? returned true, so the proc must exist;
        # but the typechecker can't prove that without re-reading the Hash.
        return Result.unsupported(
          "System action #{name.inspect} binding claimed support for platform " \
          "#{platform.inspect} but no proc was found in the platforms map. " \
          "This is a substrate bug — please file an issue."
        )
      end

      begin
        proc.call(args)
        Result.success
      rescue ex : Exception
        Result.failed(
          "System action #{name.inspect} on platform #{platform.inspect} raised " \
          "#{ex.class}: #{ex.message}"
        )
      end
    end
  end
end
