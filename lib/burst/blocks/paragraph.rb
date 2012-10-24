module Burst
  module Blocks
    class Paragraph < Basic
      attr_reader :literal_marker, :text

      def initialize(text)
        if text.strip.end_with?("::")
          @literal_marker = true
          text = text.strip.gsub(/::$/m, ':')
        else
          @literal_marker = false
        end

        @text = text
      end

      def to_html(renderer)
        "<p>\n#{renderer.render(text)}\n</p>"
      end
    end
  end
end