module Burst
  module Blocks
    class Header < Basic
      attr_accessor :text
      
      # NOTE: This deviates from the reST spec in naming. Headers are
      #       equivalent to reST section titles.
      
      def initialize(text, style)
        @text = text
        @style = style
      end
      
      def to_html(renderer)
        idx = renderer.header_hierarchy.index @style
        if idx.nil?
          renderer.header_hierarchy.push @style
          idx = renderer.header_hierarchy.length - 1
        end
        n = (idx <= 5 ? (idx + 1) : 6).to_s
        "<h#{n}>#{renderer.render(text)}</h#{n}>"
      end
      
      def inspect
        "h(#{text})"
      end
    end
  end
end