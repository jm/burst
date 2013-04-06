module Burst
  module Blocks
    module Directives
      class Function < Burst::Blocks::Directive
        def initialize(directive)
          super("function")
        end  
        
        def inspect
          "fn()"
        end
        def arguments
          @_arguments ||= super.strip
        end
        
        def name
          @name ||= self.arguments.scan(/^\w+/).first.to_s
        end
        
        def to_html(renderer)
          html = "<dl class=\"function\">\n"
          
          # Arguments
          if self.name.empty?
            html << "<dt>\n"
          else
            html << "<dt id=\"func_#{self.name}\">\n"
          end
            html << "<tt>#{self.arguments}</tt>\n"
            unless self.name.empty?
              html << "<a href=\"#func_#{self.name}\">&para;</a>\n"
            end
          html << "</dt>\n"
          
          # Block body
          html << "<dd>\n"
          # TODO: Refactor all the places this little block is called.
          unless @blocks.empty?
            html << (@blocks.map {|b| b.to_html(renderer) }.join("\n") + "\n")
          end
          html << "</dd>\n"
          
          return (html + "</dl>\n")
        end
      end#/Image
    end#/Directives
  end#/Blocks
end#/Burst
