module Burst
  module Blocks
    class Line < Basic
      def initialize(text)
        @content = text
      end
      def to_html(renderer)
        html = "<div class=\"line-block\">\n"
        # Processing line independently.
        # TODO: Maybe have the parser just give Line an array of lines instead
        #       of a string.
        html << @content.split("\n").map {|line|
          # Render the text then replace leading space with significant space.
          renderer.render(line).sub(/^\s+/) {|i| "&nbsp;" * i.length }
        }.join("<br />\n")
        return (html + "\n</div>\n")
      end
    end
  end
end
