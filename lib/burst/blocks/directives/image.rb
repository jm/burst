module Burst
  module Blocks
    module Directives
      class Image < Burst::Blocks::Basic
        def initialize(content)
          @whole_content = content.split("\n")
          @url = @whole_content.shift
        end  

        def to_html(renderer)
          "<img src='#{@url}'>"
        end
      end
    end
  end
end