module Burst
  module Blocks
    class BlockQuote < Basic
      attr_reader :text, :attribution

      def initialize(content, quote_attribution = nil)
        @text = content
        @attribution = quote_attribution
        puts "'#{content}' -- #{attribution}"
      end

      def to_html
        "<p>'#{text}' &mdash; #{attribution}"
      end
    end
  end
end