module Burst
  module Blocks
    class Explicit < Basic
      def initialize(markup_directive, text)
        @directive = markup_directive
        @content = text
      end

      def to_html(r)
        ""
      end
    end
  end
end