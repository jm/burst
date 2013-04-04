module Burst
  module Blocks
    class Directive < Basic
      attr_accessor :blocks, :type, :content, :options, :arguments, :meta
      def initialize(type)
        @type = type
        @blocks = []
        @arguments = ""
        @options = {}
        @meta = {}
        @content = ""
      end
      
      def to_html(renderer)
        ".. #{type}"
      end
    end
  end
end
