module Burst
  module Blocks
    module Directives
      class Figure < Burst::Blocks::Directive
        def initialize(directive)
          super("figure")
        end  

        def to_html(renderer)
          html = "<div class=\"figure\">\n"
          html << "<img src=\"#{@arguments.strip}\">\n"
          # TODO: Make this support caption and legend:
          # http://docutils.sourceforge.net/docs/ref/rst/directives.html#figure
          unless @blocks.empty?
            html << (@blocks.map {|b| b.to_html(renderer) }.join("\n") + "\n")
          end
          return (html + "</div>\n")
        end
        
      end#/Figure
    end#/Directives
  end#/Blocks
end#/Burst
