module Burst
  module Blocks
    module Directives
      class Admonition < Burst::Blocks::Directive
        def initialize(admonition_type, content)
          @type = admonition_type
          @content = content
          super("admonition")
        end  

        def to_html(renderer)
          "<div class='admonition #{@type}'>
            #{@renderer.render(content)}
           </div>"
        end
      end
    end
  end
end