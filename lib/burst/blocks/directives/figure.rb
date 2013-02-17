module Burst
  module Blocks
    module Directives
      class Figure < Burst::Blocks::Basic
        def initialize(content)
          @whole_content = content.split("\n")

          @url = @whole_content.shift
          @caption = @whole_content.join("\n")
        end  

        def to_html(renderer)
          "<div class='figure'>
            <img src='#{@url}'>
            #{renderer.render(@caption)}
           </div>
          "
        end
      end
    end
  end
end