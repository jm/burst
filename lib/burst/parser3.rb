module Burst
  class Parser3
    attr_accessor :current_line, :document, :previous_blank
    
    SECTION_TITLE_REGEX = /^[\!\"\#\$\%\&\'\(\)\*\+\,\-\.\/\;\<\=\>\?\@\[\\\]\^\_\`\{\|\}\~]{1,}$/
    
    TRANSITION_REGEX = /^[\!\"\#\$\%\&\'\(\)\*\+\,\-\.\/\;\<\=\>\?\@\[\\\]\^\_\`\{\|\}\~]{4,}$/

    BULLET_LIST_REGEX = /^(\s*)([\*\+\-\•\‣])(\s+)(.+)$/

    EXPLICIT_REGEX = /^(\.\.\s+)(.+)$/

    LITERAL_BLOCK_START_REGEX = /^\:\:/
    
    LITERAL_BLOCK_REGEX = /^(\s+)(.+)$/

    INDENTED_REGEX = /^(\s+)(.+)$/

    QUOTE_LITERAL_BLOCK_REGEX = /^\s*\".+/

    QUOTE_ATTRIBUTION_REGEX = /^\s*(--|---|-) (.+)/

    DOCTEST_BLOCK_REGEX = /^\>\>\> .+/

    # TODO: Unescape as much as possible
    QUOTED_LITERAL_REGEX = /^[\!\"\#\$\%\&\'\(\)\*\+\,\-\.\/\:\;\<\=\>\?\@\[\\\]\^\_\`\{\|\}\~]{1,} $/

    ENUMERATED_LIST_REGEX = /^(\s*)(\w+\.|\(?\w+\)) (.+)/

    # Explicit markup blocks
    FOOTNOTE_REFERENCE_REGEX = /^\.\. \[(.+)\] (.*)/

    ANONYMOUS_HYPERLINK_REFERENCE_REGEX = /^\.\. __\: (.+)/
    
    HYPERLINK_REFERENCE_REGEX = /^\.\. _(.+)\: (.+)/
    
    DIRECTIVE_REGEX = /^\.\. (.+)\:\:( .+)?/
    
    DIRECTIVE_OPTION_REGEX = /^:(.+):\s+(.+)/
    
    def initialize(renderer = nil)
      @inline_renderer = (renderer || InlineRenderer.new)
      super()
    end
    
    # Replace any leading tabs with 4 spaces
    def replace_tabs(line)
      line.gsub(/^\s*/) {|ws| ws.gsub("\t", "    ") }
    end
    
    def parse(content)
      @lines    = content.split("\n")
      @document = Document.new(@inline_renderer)
      
      @document.blocks = parse_body(@lines, "")
      
      # puts @document.blocks.inspect
      
      @document
    end
    
    def render(content)
      parse(content).render
    end
    
    # Consumes lines from *lines* at or greater than indent level *indent* and
    # feeds those lines to parse_block(). Returns all blocks it has found as
    # an array when it either a) runs out of input or b) runs into a lesser-
    # indented line.
    def parse_body(lines, indent)
      indent_length = indent.length
      
      blocks = []
      
      while !lines.empty?
        line = lines.shift
        line = replace_tabs(line)
        # Skip empty lines
        if line.strip.empty?
          next
        end
        if line.slice(0, indent_length) != indent
          # If the indent doesn't match, then return all blocks.
          lines.unshift line
          return blocks
        end
        
        block = parse_block(line, lines, indent)
        if block
          blocks << block
        else
          raise "No return from block parse"
        end
      end
      return blocks
    end
    
    # Consumes an entire sequence of bulleted list items.
    def handle_bullet_list(line, lines, indent)
      il = indent.length
      # /^(\s*)([\*\+\-\•\‣])(\s+)(.+)$/
      line.slice(il, line.length) =~ BULLET_LIST_REGEX
      item_indent = $1 + $2 + $3
      body_indent = $1 + " " + $3
      content = $4
      # Quick reference
      iil = item_indent.length
      
      items = []
      list = Blocks::List.new(:bullet)
      
      # Put the line back onto the queue with the indent
      lines.unshift(line)
      # While we're looking at the latest raw line and the line starts with
      # the indent we're expecting (ie. something like "- "):
      while (line = self.peek(lines)) && line.slice(il, iil) == item_indent
        # Slice off the tail of the raw line.
        content = line.slice(il + iil, line.length)
        # Take off the raw line and replace it with a line that has
        # "- " turned into "  ".
        lines.shift
        lines.unshift(indent + body_indent + content)
        
        ret = parse_body(lines, indent + body_indent)
        # Push whatever we got into the items
        li = Blocks::ListItem.new(list)
        li.blocks = ret
        items.push li
        
        # Then look for the next non-blank line.
        self.chomp_empty!(lines)
        break if lines.empty?
      end
      
      list.items = items
      return list
    end
    
    # Consumes one paragraph block.
    def handle_paragraph(line, lines, indent)
      indent_length = indent.length
      
      content = [line.slice(indent_length, line.length)]
      
      # Checks if next line is valid and shifts it off if it is.
      next_line_okay = Proc.new {
        line = self.peek(lines)
        if line.strip.empty?
          next false
        end
        if line.slice(0, indent_length) != indent
          # If the indent doesn't match, then return all blocks.
          next false
        end
        lines.shift
        true
      }
      
      while !lines.empty? && next_line_okay.call
        content.push line.slice(indent_length, line.length)
      end
      
      if content.last.end_with? "::"
        # Push on an indicator for a literal block.
        lines.unshift "#{indent}"
        lines.unshift "#{indent}::"
      end
      
      return Blocks::Paragraph.new(content.join "\n")
    end
    
    def handle_transition(line, lines, indent)
      return Blocks::Transition.new
    end
    
    def handle_wrapped_section_title(line, lines, indent)
      prefix = line
      header = lines.shift.slice(indent.length, line.length)
      suffix = lines.shift.slice(indent.length, line.length)
      
      if prefix != suffix
        # TODO: Line numbers
        raise "Prefix doesn't match suffix"
      end
      return Blocks::Header.new(header)
    end
    
    def handle_plain_section_title(line, lines, indent)
      header = line
      suffix = lines.shift#.strip
      return Blocks::Header.new(header)
    end
    
    def handle_block_quote(line, lines, indent)
      # /^(\s+)(.+)$/
      line =~ INDENTED_REGEX
      quote_indent = $1
      content = $2
      
      quote = [content]
      more = self.slurp(lines, indent + quote_indent)
      quote.push(*more) if more
      
      # Remove trailing empty lines.
      while quote.last.strip.empty?; quote.pop; end
      
      if quote.last =~ QUOTE_ATTRIBUTION_REGEX # /^\s*(--|---|-) (.+)/
        attribution = $2
        quote.pop # Remove the attribution line
      else
        attribution = nil
      end
      
      # Remove any more trailing empty lines.
      while quote.last.strip.empty?; quote.pop; end
      
      return Blocks::BlockQuote.new(quote.join("\n"), attribution)
    end
    
    # Consumes lines at a given indentation level without regard for
    # sub-indentation (used for literal blocks and block quotes).
    def slurp(lines, indent)
      indent_length = indent.length
      content = []
      while line = self.peek(lines)
        # If it hits a blank line it keeps peeking ahead for a line with the
        # right indentation level.
        maybe = []
        maybe_ahead = 1
        do_break = false
        if line.strip.empty?
          # Add the first empty line to the list of maybe lines.
          maybe << line.slice(indent_length, line.length)
          # Then start peeking ahead.
          while maybe_line = self.peek_ahead(lines, maybe_ahead)
            if maybe_line.strip.empty?
              # If line empty:
              maybe_ahead += 1
              maybe << maybe_line.slice(indent_length, maybe_line.length)
              next
            elsif maybe_line.slice(0, indent_length) == indent
              # If line not empty with correct indentation.
              break
            else
              # Not empty with incorrect indentation.
              do_break = true
              break
            end
          end
        end
        # Indentation got broken.
        break if do_break
        # Some blank lines were found
        if maybe.length > 0
          content << (maybe.join "\n")
          # Shift off all the lines that were found.
          maybe.length.times { lines.shift }
        end
        
        line = self.peek(lines)
        if line.slice(0, indent_length) == indent
          content << line.slice(indent_length, line.length)
          lines.shift # Pull off this line
        else
          # Incorrect indentation
          break
        end
      end
      return content
    end
    
    def handle_literal_block(line, lines, indent)
      # /^(\s+)(.+)$/
      line =~ LITERAL_BLOCK_REGEX
      literal_indent = $1
      content = $2
      
      code = [content]
      more = self.slurp(lines, indent + literal_indent)
      code.push(*more) if more
      
      return Blocks::Literal.new(code.join "\n")
    end
    
    # Consumes all empty lines it can and returns a non-blank line.
    def slurp_empty!(lines)
      while line = self.peek(lines)
        lines.shift
        if line.strip.empty?
          next
        else
          return line
        end
      end
    end
    
    # Parses a block based on it's first line. Handlers are allowed (and
    # encouraged) to consume additional lines off of *lines* on their own.
    def parse_block(line, lines, indent)
      test_line = line.slice(indent.length, line.length)
      
      if test_line =~ BULLET_LIST_REGEX
        handle_bullet_list(line, lines, indent)
      
      # Check if wrapped section title or a transition  
      elsif test_line =~ SECTION_TITLE_REGEX
        if self.peek(lines).to_s.strip.empty?
          handle_transition(line, lines, indent)
        else
          handle_wrapped_section_title(line, lines, indent)
        end
      
      # Check if next line is a section title line
      elsif !line.strip.empty? && self.peek(lines).to_s =~ SECTION_TITLE_REGEX
        handle_plain_section_title(line, lines, indent)
      
      elsif test_line =~ LITERAL_BLOCK_START_REGEX
        lines.shift # Skip over this line
        # Grab the next non-empty line
        line = self.slurp_empty!(lines)
        line = line.slice(indent.length, line.length)
        handle_literal_block(line, lines, indent)
      
      elsif test_line =~ INDENTED_REGEX
        handle_block_quote(line, lines, indent)
      
      # Default to paragraph
      else
        handle_paragraph(line, lines, indent)
      end
    end
    
    
    def peek(lines)
      lines[0]
    end
    def peek_ahead(lines, n)
      lines[n]
    end
    # Eats up any empty lines it can but leave the most recent non-empty one
    # on the queue (unlike slurp_empty! which shifts it off and returns it).
    def chomp_empty!(lines)
      while !lines.empty? && self.peek(lines).strip.empty?
        lines.shift
      end
    end
    
  end
end

