module Burst
  module Blocks
    class Header < Basic
      attr_accessor :text
      
      def initialize(text)
        @text = text
        puts "\t#{text}"
      end

      def to_html
        "<h1>#{text}</h1>"
      end
    end
  end
end