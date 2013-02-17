module Burst
  module Blocks
    class List < Basic
      def initialize(list_type, element_list)
        @type = list_type
        @elements = element_list
        @elements.map! do |element|
          parser = Burst::Parser.new
          parser.parse(element)
        end
      end

      def to_html(renderer)
        html = "<ul>\n"

        @elements.each do |element|
          html << "<li>\n#{element.render}\n</li>\n"
        end

        html << "</ul>"
      end
    end
  end
end