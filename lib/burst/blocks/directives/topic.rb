module Burst
  module Blocks
    module Directives
      class Topic < Burst::Blocks::Directive
        def initialize(directive)
          super(directive) # directive = "topic"
        end
        
        def to_html(renderer)
          html = "<div class=\"topic\">\n"
          unless @arguments.strip.empty?
            html << "<p class=\"topic-title\">#{@arguments.strip}</p>\n"
          end
          unless @blocks.empty?
            html << (@blocks.map {|b| b.to_html(renderer) }.join("\n") + "\n")
          end
          return (html + "</div>\n")
        end
        
      end#/Topic
    end#/Directives
  end#/Blocks
end#/Burst
