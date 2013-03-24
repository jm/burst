module Burst
  module Blocks
    class Transition < Basic
      def to_html(r)
        "<hr />"
      end
      def inspect
        "----"
      end
    end
  end
end