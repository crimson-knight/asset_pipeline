require "../view"

module UI
  class Form < View
    record Field,
      label : String = "",
      content : View? = nil

    record FormSection,
      header : String? = nil,
      fields : Array(Field) = [] of Field,
      footer : String? = nil

    property sections : Array(FormSection) = [] of FormSection

    def initialize
      # Default container-query root so `@container form (...)` rules and
      # the per-element render output both pick up `container-type:
      # inline-size; container-name: form;` without needing the registered
      # class CSS to be loaded.
      @container_query_name = "form"
    end

    def add_section(header : String? = nil, footer : String? = nil) : FormSection
      section = FormSection.new(header: header, footer: footer)
      @sections << section
      section
    end

    def field_count : Int32
      sections.sum(&.fields.size)
    end

    def accept(visitor : PlatformVisitor)
      visitor.visit(self)
    end
  end
end
