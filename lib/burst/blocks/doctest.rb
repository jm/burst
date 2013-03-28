module Burst
  module Blocks
    class Doctest < Basic
      attr_accessor :content
      def initialize(text)
        @content = text
      end

      def to_html(r)
        "<pre class=\"doctest\">\n#{@content}\n</pre>"
      end
      def inspect
        "d(#{@content.inspect})"
      end
      
    end
  end
end