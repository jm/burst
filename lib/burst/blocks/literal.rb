module Burst
  module Blocks
    class Literal < Basic
      def initialize(text)
        @content = text
      end

      def to_html(r)
        "<pre>\n#{@content}\n</pre>"
      end
    end
  end
end