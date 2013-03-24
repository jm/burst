module Burst
  module Blocks
    module Directives
      class Figure < Burst::Blocks::Directive
        def initialize(content)
          super("figure")
        end  

        def to_html(renderer)
          "<div class='figure'>
            <img src='#{@arguments.strip}'>
            #{@blocks.map {|b| b.to_html(renderer) }.join("\n")}
           </div>
          "
        end
      end
    end
  end
end