module Burst
  module Blocks
    class Literal < Basic
      def initialize(text)
        @content = text
        @content.split("\n").each {|l| puts "\t| #{l}"}
      end

      def to_html(r)
        "<pre>\n#{@content}\n</pre>"
      end
    end
  end
end