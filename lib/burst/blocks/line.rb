module Burst
  module Blocks
    class Line < Basic
      def initialize(text)
        @content = text

        # TODO: Process line things here
      end
      def to_html(renderer)
        # "<pre>\n#{@content}\n</pre>"
        html = "<div class=\"line-block\">\n"
        html << @content.split("\n").map {|line|
          # Replace leading space with significant space
          line.sub(/^\s+/) {|i| "&nbsp;" * i.length }
        }.join("<br />\n")
        return (html + "\n</div>\n")
        
      end
    end
  end
end