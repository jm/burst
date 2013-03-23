module Burst
  module Blocks
    class Literal < Basic
      attr_accessor :content
      def initialize(text)
        @content = text
      end

      def to_html(r)
        "<pre>\n#{@content}\n</pre>"
      end
    end
  end
end