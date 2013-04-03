module Burst
  module Blocks
    class Basic
      def to_html(renderer)
        raise NotImplementedError, "Missing #to_html for #{self.class.name}"
      end
      def inspect
        raise NotImplementedError, "Missing #inspect for #{self.class.name}"
      end
      def to_s; inspect; end
      def ==(other)
        raise NotImplementedError, "Missing #== for #{self.class.name}"
      end
    end
  end
end
