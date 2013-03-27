module Burst
  module Blocks
    class ListItem < Basic
      attr_accessor :blocks, :parent, :marker
      
      def initialize(parent)
        @parent = parent
        @blocks = []
        @marker = nil
      end
      
      def to_html(renderer)
        html = "<li>\n"
        @blocks.each do |block|
          html << (block.to_html(renderer) + "\n")
        end
        html << "</li>\n"
        return html
      end
      def inspect
        "li(#{@blocks.map(&:inspect).join(' ')})"
      end
    end
    
    class List < Basic
      HTML_TYPES = ["1", "A", "a", "I", "i"]
      
      attr_accessor :items, :parent, :type
      def initialize(list_type)
        @type = list_type
        @items = []
      end
      
      def opening_tag
        if @type == :enumerated
          typ   = false
          if first = @items.first
            marker = first.marker.gsub(/[^A-Za-z0-9]/, '')
            HTML_TYPES.each do |t|
              if marker == t
                typ = marker
                break
              end
            end
          end
          typ ? "<ol type=\"#{typ}\">" : "<ol>"
        else
          '<ul>'
        end
      end
      def closing_tag
        (@type == :enumerated) ? '</ol>' : '</ul>'
      end
      
      def to_html(renderer)
        html = "#{self.opening_tag}\n"
        @items.each do |item|
          html << item.to_html(renderer)
        end
        html << "#{self.closing_tag}\n"
        return html
      end
      def inspect
        "#{@type.to_s}(#{@items.map(&:inspect).join(',')})"
      end
    end
  end
end
