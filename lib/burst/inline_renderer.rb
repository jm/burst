require 'digest/sha1'
require 'uri'

module Burst
  class InlineRenderer
    DEFAULT_FOOTNOTE_SYMBOLS = [
      "asterisk", "dagger", "Dagger", "sect", "para",
      "numbersign", "spades", "hearts", "diams", "clubs"
    ]
    
    # TODO: Document this regex
    INTERPRETED_TEXT_REGEX = /(?<!_)(?<marker>:(?<role>[\w\-\+\.]+):)?`(?<text>[^`]+)`\g<marker>?/m
    
    attr_accessor :content, :header_hierarchy
    
    def initialize
      # pass
    end

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
      @header_hierarchy = []
      @interpreted_texts = {}
      
      @content = content

      format_interpreted_text
      replace_strong_emphasis 
      replace_emphasis
      replace_inline_literals
      replace_internal_targets
      replace_anonymous_hyperlinks
      replace_hyperlink_references
      replace_footnote_references
      replace_substitution_references
      replace_interpreted_text

      @content
    end

    def replace_strong_emphasis
      @content.gsub!(/\*\*(.+?)\*\*/m, '<strong>\1</strong>')
    end

    def replace_emphasis
      @content.gsub!(/\*([^*]+?)\*/m, '<em>\1</em>')
    end

    def replace_inline_literals
      @content.gsub!(/\`\`(.+?)\`\`/m, '<code>\1</code>')
    end

    def replace_internal_targets
      # TODO: Make this match the spec
      #       See: http://docutils.sourceforge.net/docs/ref/rst/restructuredtext.html#inline-internal-targets
      @content.gsub!(/_`([^`]+)`/m) do |match|
        "<a href='[[hlr:#{Digest::SHA1.hexdigest($1)}]]'>#{$1}</a>"
      end
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
    
    module Roles
      class << self
        def title_reference(key, text)
          "<cite>[[it:#{key}]]</cite>"
        end
        def func_reference(key, text)
          text = text.strip
          # TODO: Sanitize text (remove any "s)
          "<a href=\"#func_#{text}\">#{text}</a>"
        end
        def subscript_reference(key, text)
          "<sub>#{text}</sub>"
        end
        def superscript_reference(key, text)
          "<sup>#{text}</sup>"
        end
      end# self
    end#modules Roles
    
    def save_interpreted_text(text)
      key = Digest::SHA1.hexdigest(text)
      @interpreted_texts[key] = text
      return [key, text]
    end
    
    def format_interpreted_text
      @content.gsub!(INTERPRETED_TEXT_REGEX) do |str|
        match = $~
        role = match["role"].to_s
        key, text = save_interpreted_text(match["text"])
        if role.empty?
          # TODO: Do some formatting?
          Roles.title_reference(key, text)
        else
          # Handle role
          if role == "func"
            Roles.func_reference(key, text)
          elsif role == "subscript" || role == "sub"
            Roles.subscript_reference(key, text)
          elsif role == "superscript" || role == "sup"
            Roles.superscript_reference(key, text)
          else
            raise RenderError.new("Don't know what to do with role: #{role}")
          end
        end
      end
      # @content.gsub!(/\`(.+?)\`/m, '\1')
    end
    def replace_interpreted_text
      @interpreted_texts.each do |key, value|
        @content.gsub!("[[it:#{key}]]", value)
      end
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
      @content.gsub!(/(\w+)(?:__\W)/m) do |match| 
        "<a href='[[anon-hl]]'>#{$1}</a>"
      end

      @content.gsub!(/`([^`]+)`__\W/m) do |match|
        "<a href='[[anon-hl]]'>#{$1}</a>"
      end
    end
  end
end
