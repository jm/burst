module Burst
  module Blocks
    module Directives
      class Admonition < Burst::Blocks::Basic
        def initialize(admonition_type, content)
          @type = admonition_type
          @content = content
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