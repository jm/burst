module Burst
  module Blocks
    class Paragraph < Basic
      attr_reader :literal_marker, :text

      def initialize(text)
        @text = text
        @literal_marker = text.end_with?("::")
      end

      def to_html
        "<p>\n#{text}\n</p>"
      end
    end
  end
end