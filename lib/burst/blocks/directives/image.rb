module Burst
  module Blocks
    module Directives
      class Image < Burst::Blocks::Directive
        def initialize(directive)
          @whole_content = content.split("\n")
          @url = @whole_content.shift
          super("image")
        end  

        def to_html(renderer)
          "<img src=\"#{@url}\" />\n"
        end
      end#/Image
    end#/Directives
  end#/Blocks
end#/Burst
