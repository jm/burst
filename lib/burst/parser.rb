module Burst
  class Parser
    attr_accessor :lines, :stack, :current_line, :document

    # TODO: Unescape as much as possible
    SECTION_HEADER_REGEX = /^[\!\"\#\$\%\&\'\(\)\*\+\,\-\.\/\:\;\<\=\>\?\@\[\\\]\^\_\`\{\|\}\~]{4,}$/

    BULLET_LIST_REGEX = /^([\*\+\-]) (.+)/

    EXPLICIT_REGEX = /^\.\. .+/

    LITERAL_BLOCK_START_REGEX = /^\:\:/

    LITERAL_BLOCK_REGEX = /^\s.+/

    QUOTE_LITERAL_BLOCK_REGEX = /^\s*\".+/

    QUOTE_ATTRIBUTION_REGEX = /^\s*(--|---|-) (.+)/

    DOCTEST_BLOCK_REGEX = /^\>\>\> .+/

    # TODO: Unescape as much as possible
    QUOTED_LITERAL_REGEX = /^[\!\"\#\$\%\&\'\(\)\*\+\,\-\.\/\:\;\<\=\>\?\@\[\\\]\^\_\`\{\|\}\~]{1,} $/

    ENUMERATED_LIST_REGEX = /^(\w+\.|\(?\w+\)) (.+)/

    def parse(content)
      @lines = content.split("\n")
      @document = []

      while (line = @lines.shift)
        @current_line = line
        process_current_line
      end
    end

    def process_current_line
      # Skip dat blank
      if current_line.empty?
        return nil
      # A section line, followed by text, followed by another section line, followed by a blank line
      # == section header
      elsif (current_line =~ SECTION_HEADER_REGEX) && !next_line.empty? && (second_next_line =~ SECTION_HEADER_REGEX) && line_at(2).empty?
        # TODO: Handle header levels
        puts "HEY! HEADER!"
        handle_header(next_line)
        remove_next_line
      # Line of punctuation characters followed by a blank line
      # == transition
      elsif (current_line =~ SECTION_HEADER_REGEX) && next_line.empty?
        puts "HEY TRANSITION!"
        handle_transition
      # Non-blank current line followed by punctuation character line
      # == section header
      elsif !current_line.empty? && (next_line =~ SECTION_HEADER_REGEX)
        puts "HEY HEADER WITH UNDER ONLY!"
        handle_header(current_line)
      # Starts with - or whatever and followed by blank line or second paragraph
      elsif current_line =~ BULLET_LIST_REGEX
        puts "HEY LIST!"
        handle_list(:bullet)
      # Starts with something like (a) or 1. or 3)
      elsif current_line =~ ENUMERATED_LIST_REGEX
        puts "HEY ENUMERATED LIST!"
        handle_list(:enumerated)
      elsif current_line =~ QUOTE_LITERAL_BLOCK_REGEX
        handle_block_quote
      # Explicit markup.  Could be a footnote or something else.
      elsif current_line =~ EXPLICIT_REGEX
        puts "EXPLICIT!!"
        handle_explicit
      # Has the :: literal starter
      elsif (current_line =~ LITERAL_BLOCK_START_REGEX) && next_line.empty?
        remove_next_line
        skip_current_line

        handle_literal
      # An indented literal block with the :: on the previous paragraph
      elsif (current_line =~ LITERAL_BLOCK_REGEX) && (last_document_element.is_a?(Blocks::Paragraph) && last_document_element.literal_marker)
        handle_literal
      # A doctest block
      elsif current_line =~ DOCTEST_BLOCK_REGEX
        handle_literal
      # Quoted literal text
      elsif (current_line =~ QUOTED_LITERAL_REGEX) && (last_document_element.is_a?(Blocks::Paragraph) && last_document_element.literal_marker)
        handle_quoted_literal
      else
        puts "probably paragraph yo"
        handle_paragraph
      end
    end

    def handle_quoted_literal
      puts "whoa quoted literalllll"
      @current_line += "\n"
      # TODO: Finish this      
    end

    def handle_literal
      puts "literalness"
      @current_line += "\n"
      slurp_remaining_literal_block

      @document << Blocks::Literal.new(current_line)
    end

    def handle_paragraph
      slurp_remaining_block
      @document << Blocks::Paragraph.new(current_line)
      remove_next_line
    end

    def handle_explicit
      @document << Blocks::Explicit.new("thing", current_line)
    end

    def handle_header(text)
      @document << Blocks::Header.new(text)
      remove_next_line
    end

    def handle_transition
      @document << Blocks::Transition.new
      remove_next_line
    end

    def handle_block_quote
      slurp_remaining_literal_block
      # TODO: Clean this up; we basically just need to join up the lines with spaces
      # rather than \n and remove the quotes
      @current_line = current_line.split("\n").map {|l| l.strip}.join(" ").gsub(/^"(.*)"$/, '\1')

      # Does it have an attribution?
      # TODO: Figure out how to add actual em dashes etc. to the regex
      attribution = nil
      if second_next_line =~ QUOTE_ATTRIBUTION_REGEX
        attribution = second_next_line.match(QUOTE_ATTRIBUTION_REGEX)[2]
        remove_next_line
        remove_next_line
      end

      @document << Blocks::BlockQuote.new(current_line, attribution)
    end

    def handle_list(list_type)
      regexen = {
        :enumerated => ENUMERATED_LIST_REGEX,
        :bullet => BULLET_LIST_REGEX
      }

      list_match_regex = regexen[list_type]
      elements = []
      slurp_remaining_list_block(list_match_regex, 2)

      elements << current_line.gsub(list_match_regex, '\2')
      remove_next_line

      while (next_line =~ list_match_regex)
        @current_line = @lines.shift.gsub(list_match_regex, '\2')
        slurp_remaining_list_block(list_match_regex, 2)
        elements << current_line
        remove_next_line
      end

      @document << Blocks::List.new(list_type, elements)
    end

    def indented?(text)
      false
    end

    def next_line
      line_at(0)
    end

    def second_next_line
      line_at(1)
    end

    def line_at(index)
      @lines[index]
    end

    def remove_next_line
      @lines.shift
    end

    def skip_current_line
      @current_line = @lines.shift
    end

    def slurp_remaining_literal_block
      until next_line.nil? || !(next_line =~ LITERAL_BLOCK_REGEX)
        @current_line << @lines.shift + "\n"
      end
    end

    def slurp_remaining_block
      until next_line.nil? || next_line.empty?
        @current_line << @lines.shift
      end
    end

    def slurp_remaining_list_block(list_regex, indent)
      indent_regex = /^\s{#{indent},}/

      until next_line.nil? || next_line =~ list_regex || (!(next_line.empty?) && !(next_line =~ indent_regex)) || (!(second_next_line.empty?) && !(second_next_line =~ indent_regex))
        @current_line << "#{@lines.shift[indent..-1]}\n"
      end
    end

    def last_document_element
      @document.last
    end
  end
end