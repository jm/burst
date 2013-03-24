module Burst
  module Blocks
    class ListItem < Basic
      attr_accessor :blocks, :parent
      
      def initialize(parent)
        @parent = parent
        @blocks = []
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
      attr_accessor :items, :parent, :type
      def initialize(list_type)
        @type = list_type
        @items = []
      end
      
      def to_html(renderer)
        html = "<ul>\n"
        @items.each do |item|
          html << item.to_html(renderer)
        end
        html << "</ul>\n"
        return html
      end
      def inspect
        "#{@type.to_s}(#{@items.map(&:inspect).join(',')})"
      end
    end
  end
end
