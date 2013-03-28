module Burst
  module Blocks
    module Directives
      class Admonition < Burst::Blocks::Directive
        def initialize(admonition_type)
          @admonition_type = admonition_type
          super("admonition")
        end
        
        def to_html(renderer)
          html = "<div class=\"admonition #{@admonition_type.to_s}\">\n"
          unless @blocks.empty?
            html << (@blocks.map {|b| b.to_html(renderer) }.join("\n") + "\n")
          end
          return (html + "</div>\n")
        end
      end
    end
  end
end