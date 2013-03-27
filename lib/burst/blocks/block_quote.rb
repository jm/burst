module Burst
  module Blocks
    class BlockQuote < Basic
      attr_reader :text, :attribution

      def initialize(content, quote_attribution = nil)
        @text = content
        @attribution = quote_attribution
      end

      def to_html(renderer)
        if @attribution
          "<blockquote>#{renderer.render(text)}<br /><br /><cite>&mdash; #{attribution}</cite></blockquote>"
        else
          "<blockquote>#{renderer.render(text)}</blockquote>"
        end
      end
      def inspect
        short = text.slice(0, 10)
        if text.length > 10
          short << "..."
        end
        out = "q(#{text.length.to_s}:#{short.inspect}"
        if @attribution
          out << ",#{@attribution}"
        end
        return out + ")"
      end
      
    end
  end
end