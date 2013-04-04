module Burst
  module Blocks
    module Directives
      class Code < Burst::Blocks::Directive
        def initialize(directive, content = nil)
          super(directive) # directive = "code"
          @content = content
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
