module Burst
  module Blocks
    class Explicit
      # Required admonitions per the rST spec
      ADMONITIONS = %w{admonition attention danger caution error hint important note tip warning}
      DIRECTIVES = {
        "figure" => Burst::Blocks::Directives::Figure,
        "topic" => Burst::Blocks::Directives::Topic,
        "image" => Burst::Blocks::Directives::Image
        # "code" => Burst::Blocks::Directives::Code
      }

      def self.new_for_params(markup_directive, text = "")
        if markup_directive == "image"
          Burst::Blocks::Directives::Image.new(text)
        elsif DIRECTIVES.has_key? markup_directive
          DIRECTIVES[markup_directive].new(markup_directive)
          # Burst::Blocks::Directives::Figure.new(text)
        elsif ADMONITIONS.include?(markup_directive)
          Burst::Blocks::Directives::Admonition.new(markup_directive)
        else
          puts "WARNING: I don't know what a `#{markup_directive}` directive is.  Sorry about that.  Except not really."
          Burst::Blocks::Directive.new(markup_directive)
        end
      end
      
      def to_html(renderer)
        "explicit()"
      end
      
    end
  end
end