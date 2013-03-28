module Burst
  module Blocks
    module Directives
      class Figure < Burst::Blocks::Directive
        def initialize(content)
          super("figure")
        end  

        def to_html(renderer)
          html = "<div class=\"figure\">\n"
          html << "<img src=\"#{@arguments.strip}\">\n"
          unless @blocks.empty?
            html << (@blocks.map {|b| b.to_html(renderer) }.join("\n") + "\n")
          end
          return (html + "</div>")
        end
      end
    end
  end
end