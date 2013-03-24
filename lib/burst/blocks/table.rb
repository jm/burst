module Burst
  module Blocks
    class TableCell < Basic
      attr_accessor :blocks, :parent
      def initialize(parent, blocks = nil)
        @parent = parent
        @blocks = blocks || []
      end
      
      # TODO: Maybe remove this now that TableHeader does its own thing.
      def opening_tag
        @parent.is_a?(TableHeader) ? '<th>' : '<td>'
      end
      def closing_tag
        @parent.is_a?(TableHeader) ? '</th>' : '</td>'
      end
      
      def to_html(renderer)
        html = "#{self.opening_tag}\n"
        @blocks.each do |block|
          html << (block.to_html(renderer) + "\n")
        end
        html << "#{self.closing_tag}\n"
        return html
      end
      
      def inspect
        "tc(#{@blocks.length.to_s})"
      end
    end
    
    class TableRow < Basic
      attr_accessor :cells
      
      def initialize
        @cells = []
      end
      
      def to_html(renderer)
        h = "<tr>\n"
        @cells.each do |cell|
          h << (cell.to_html(renderer) + "\n")
        end
        return (h + "</tr>\n")
      end
      def inspect
        "tr(#{@cells.length.to_s})"
      end
    end
    class TableHeader < TableRow
      def to_html(renderer)
        h = "<tr>\n"
        # NOTE: Cells in TableHeader are just plain text
        @cells.each do |cell|
          h << ("<th>" + renderer.render(cell) + "</th>\n")
        end
        return (h + "</tr>\n")
      end
      def inspect
        "th(#{@cells.length.to_s})"
      end
    end
    
    class Table < Basic
      attr_accessor :rows
      def initialize
        @rows = []
      end
      
      def to_html(renderer)
        h = "<table>\n"
        @rows.each do |row|
          h << (row.to_html(renderer) + "\n")
        end
        return (h + "</table>\n")
      end
      def inspect
        "t(#{@rows.length.to_s})"
      end
      
    end
  end
end
