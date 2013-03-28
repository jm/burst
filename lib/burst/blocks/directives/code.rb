module Burst
  module Blocks
    module Directives
      class Code < Burst::Blocks::Directive
        def initialize(directive, content = nil)
          @content = content
          super(directive) # directive = "code"
        end
        
        def to_html(renderer)
          html = "<div class=\"code\">\n"
          # TODO: Syntax highlighting
          html << "<pre>#{@content}</pre>\n"
          return (html + "</div>\n")
        end
        
      end#/Code
    end#/Directives
  end#/Blocks
end#/Burst
