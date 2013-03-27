module Burst
  module Blocks
    module Explicits
      class Footnote < Burst::Blocks::Basic
        attr_accessor :blocks, :label
        def initialize(label, blocks = nil)
          @label = label
          @blocks = (blocks || [])
        end
        
        # TODO: Proper rendering
        def to_html(renderer)
          "Footnote: #{@label}"
        end
        
        def inspect
          "fn(#{@label},#{@blocks.length})"
        end
      end
    end
  end
end
