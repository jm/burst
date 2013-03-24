module Burst
  module Blocks
    class Header < Basic
      attr_accessor :text

      def initialize(text)
        @text = text
      end

      def to_html(renderer)
        "<h1>#{renderer.render(text)}</h1>"
      end
      def inspect
        "h(#{text})"
      end
    end
  end
end