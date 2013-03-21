module Burst
  module Blocks
    class List < Basic
      attr_accessor :elements, :parent, :type
      def initialize(list_type, element_list = nil)
        @type = list_type
        
        if element_list
          @elements = element_list
          @elements.map! do |element|
            parser = Burst::Parser.new
            parser.parse(element)
          end
        else
          @elements = []
        end
      end
      
      def to_html(renderer)
        html = "<ul>\n"
        render_item = Proc.new do |el|
          if el.is_a? String
            renderer.render(el)
          else
            el.to_html(renderer)
          end
        end
        
        @elements.each do |element|
          # Handle sub-blocks
          if element.is_a? Array
            element = element.map {|el| render_item.call(el) }.join "\n"
          else
            element = render_item.call(element)
          end
          html << "<li>\n#{element}\n</li>\n"
        end
        html << "</ul>\n"
      end
    end
  end
end
