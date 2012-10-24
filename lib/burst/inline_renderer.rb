require 'digest/sha1'
require 'uri'

module Burst
  class InlineRenderer
    attr_accessor :content

    DEFAULT_FOOTNOTE_SYMBOLS = [
      "asterisk", "dagger", "Dagger", "sect", "para",
      "numbersign", "spades", "hearts", "diams", "clubs"
    ]

    def next_footnote_number
      @footnote_index ||= 0
      @footnote_index += 1
    end

    def next_footnote_symbol(include_html_entity=true)
      @footnote_symbols = DEFAULT_FOOTNOTE_SYMBOLS unless @footnote_symbols && !@footnote_symbols.empty?

      include_html_entity ? "&#{@footnote_symbols.shift};" : @footnote_symbols.shift
    end

    def reset_footnote_sequences!
      @footnote_index = 0
      @footnote_symbols = DEFAULT_FOOTNOTE_SYMBOLS
    end

    def render(content)
      @content = content

      replace_strong_emphasis 
      replace_emphasis
      replace_inline_literals
      replace_internal_targets
      replace_anonymous_hyperlinks
      replace_hyperlink_references
      replace_interpreted_text
      replace_footnote_references
      replace_substitution_references

      @content
    end

    def replace_strong_emphasis
      @content.gsub!(/\*\*(.+?)\*\*/m, '<strong>\1</strong>')
    end

    def replace_emphasis
      @content.gsub!(/\*(.+?)\*/m, '<em>\1</em>')
    end

    def replace_inline_literals
      @content.gsub!(/\`\`(.+?)\`\`/m, '<code>\1</code>')
    end

    def replace_internal_targets
      @content.gsub!(/\*\*(.+?)\*\*/m, '<strong>\1</strong>')
    end

    def replace_hyperlink_references
      @content.gsub!(/`(.+) \<(.+)\>`(?:_\W)/m) do |match| 
        "<a href='#{$2}'>#{$1}</a>"
      end

      @content.gsub!(/`(.+)`(?:_\W)/m) do |match| 
        "<a href='[[hlr:#{Digest::SHA1.hexdigest($1)}]]'>#{$1}</a>#{$2}"
      end

      # We'll post-process these to match references
      @content.gsub!(/(\w+)(?:_\W)/m) do |match| 
        "<a href='[[hlr:#{Digest::SHA1.hexdigest($1)}]]'>#{$1}</a>#{$2}"
      end
    end

    def replace_interpreted_text
      @content.gsub!(/\`(.+?)\`/m, '\1')
    end

    def replace_footnote_references
      @content.gsub!(/\[(\d+?|#|\*)\]_/m) do |match|
        match.gsub!(/\[(\d+?|#|\*)\]_/, '\1')

        link_text = ""
        anchor = ""
        
        if match == "#"
          number = next_footnote_number
          anchor = "footnote-#{number}"
          link_text = number
        elsif match == "*"
          symbol = next_footnote_symbol(false)
          anchor = "footnote-#{symbol}"
          link_text = "&#{symbol};"
        else
          anchor = "footnote-#{match}"
          link_text = match
        end
        
        "[<a href='##{anchor}'>#{link_text}</a>]"
      end
    end

    def replace_substitution_references
      # We'll post-process these to match references
      @content.gsub!(/\|(.+)\|/m) do |match| 
        "[[subr:#{Digest::SHA1.hexdigest($1)}]]"
      end
    end

    def replace_anonymous_hyperlinks
      @content.gsub!(/`(.+)`__\W/m) do |match| 
        "<a href='[[anon-hl]]'>#{$1}</a>"
      end
    end
  end
end