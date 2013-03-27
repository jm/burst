module Burst
  class NewParser
    attr_accessor :current_line, :document, :previous_blank, :inline_renderer,
                  :line_number, :parent
    
    SECTION_TITLE_REGEX = /^[\!\"\#\$\%\&\'\(\)\*\+\,\-\.\/\;\<\=\>\?\@\[\\\]\^\_\`\{\|\}\~]{1,}$/
    
    TRANSITION_REGEX = /^[\!\"\#\$\%\&\'\(\)\*\+\,\-\.\/\;\<\=\>\?\@\[\\\]\^\_\`\{\|\}\~]{4,}$/
    
    LINE_BLOCK_REGEX = /^(\s*)(\|\s+)(.+)$/
    
    BULLET_LIST_REGEX     = /^(\s*)([\*\+\-\•\‣])(\s+)(.+)$/
    ENUMERATED_LIST_REGEX = /^(\s*)(\w+\.|\(?\w+\))(\s+)(.+)$/

    EXPLICIT_REGEX = /^\.\.\s+(.+)$/

    LITERAL_BLOCK_START_REGEX = /^\:\:/
    
    LITERAL_BLOCK_REGEX = /^(\s+)(.+)$/
    
    INDENTED_REGEX = /^(\s+)(.+)$/

    QUOTE_LITERAL_BLOCK_REGEX = /^\s*\".+/

    QUOTE_ATTRIBUTION_REGEX = /^\s*(--|---|-) (.+)/

    DOCTEST_BLOCK_REGEX = /^\>\>\> .+/

    # TODO: Unescape as much as possible
    QUOTED_LITERAL_REGEX = /^[\!\"\#\$\%\&\'\(\)\*\+\,\-\.\/\:\;\<\=\>\?\@\[\\\]\^\_\`\{\|\}\~]{1,} $/
    
    # Explicit markup blocks
    FOOTNOTE_REFERENCE_REGEX = /^\.\. \[(.+)\](.*)/

    ANONYMOUS_HYPERLINK_REFERENCE_REGEX = /^\.\. __\: (.+)/
    
    HYPERLINK_REFERENCE_REGEX = /^\.\. _(.+)\: (.+)/
    
    DIRECTIVE_REGEX = /^\.\.\s+(.+)\:\:( .+)?/
    
    DIRECTIVE_OPTION_REGEX = /^:(.+):\s+(.+)/
    
    TABLE_REGEX = /^(\s*)(\+(?:-+\+)+)/
    TABLE_HEADER_REGEX = /^\+(?:=+\+)+/
    TABLE_ROW_REGEX    = /^\+(?:-+\+)+/
    
    SIMPLE_TABLE_REGEX = /^(\s*)(=+(?:\s+=+)*)/
    
    def initialize(renderer = nil)
      @inline_renderer = (renderer || InlineRenderer.new)
    end
    
    # Set up a subparser that pulls in its parent's renderer and document.
    def self.new_subparser(parent)
      parser = self.new()
      parser.inline_renderer = parent.inline_renderer
      parser.document        = parent.document
      parser.parent          = parent
      return parser
    end
    
    def parse(content)
      @line_number = 0
      @lines    = content.split("\n")
      @document = Document.new(@inline_renderer)
      
      @document.blocks = parse_body("")
      
      # puts @document.blocks.inspect
      
      @document
    end
    
    # Returns just blocks instead of a full document.
    def parse_thin(content)
      @line_number = (@parent ? @parent.line_number : 0)
      @lines = content.split("\n")
      return parse_body("")
    end
    
    def render(content)
      parse(content).render
    end
    
    # Consumes lines from *lines* at or greater than indent level *indent* and
    # feeds those lines to parse_block(). Returns all blocks it has found as
    # an array when it either a) runs out of input or b) runs into a lesser-
    # indented line.
    def parse_body(indent)
      indent_length = indent.length
      
      blocks = []
      
      while !@lines.empty?
        line = self.shift
        line = replace_tabs(line)
        # Skip empty lines
        if line.strip.empty?
          next
        end
        if line.slice(0, indent_length) != indent
          # If the indent doesn't match, then return all blocks.
          self.unshift line
          return blocks
        end
        
        block = parse_block(line, indent)
        if block
          blocks << block
        elsif block === false
          # Explicitly returning false indicates to not include the block in
          # the output (used with hyperlink references and such).
        else
          raise self.parse_error("No return from block parse")
        end
      end
      return blocks
    end
    
    # Parses a block based on it's first line. Handlers are allowed (and
    # encouraged) to consume additional lines off of *lines* on their own.
    def parse_block(line, indent)
      test_line = line.slice(indent.length, line.length)
      
      if test_line =~ TABLE_REGEX
        handle_table(line, indent)
        
      elsif test_line =~ SIMPLE_TABLE_REGEX
        handle_simple_table(line, indent)
      
      elsif test_line =~ LINE_BLOCK_REGEX
        handle_line_block(line, indent)
      
      elsif test_line =~ BULLET_LIST_REGEX
        handle_bullet_list(line, indent)
      
      elsif test_line =~ ENUMERATED_LIST_REGEX
        handle_enumerated_list(line, indent)
      
      # Check if wrapped section title or a transition  
      elsif test_line =~ SECTION_TITLE_REGEX
        if self.peek.to_s.strip.empty?
          handle_transition(line, indent)
        else
          handle_wrapped_section_title(line, indent)
        end
      
      # Check if next line is a section title line
      elsif !line.strip.empty? && self.peek.to_s =~ SECTION_TITLE_REGEX
        handle_plain_section_title(line, indent)
      
      elsif test_line =~ LITERAL_BLOCK_START_REGEX
        # Grab the next non-empty line
        line = self.slurp_empty!
        line = line.slice(indent.length, line.length)
        handle_literal_block(line, indent)
      
      elsif test_line =~ INDENTED_REGEX
        handle_block_quote(line, indent)
      
      elsif test_line =~ DOCTEST_BLOCK_REGEX
        handle_doctest(line, indent)
      
      elsif test_line =~ EXPLICIT_REGEX
        handle_explicit(line, indent)
      
      # Default to paragraph
      else
        handle_paragraph(line, indent)
      end
    end
    
    # HANDLERS ----------------------------------------------------------------
    
    # All handlers are of the format handle_...(line, indent). *line* is the
    # current line to be handled (handlers are allowed to shift more lines
    # off of the line queue) and *indent* is a string of spaces indicating
    # the base indentation level of the current line.
    
    # Consumes an entire sequence of bulleted list items.
    def handle_bullet_list(line, indent)
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
      self.unshift(line)
      
      while (line = self.peek) && # Latest line
            line.start_with?(indent) && # Enough indent
            line.slice(il, iil) == item_indent # Matching current item format
      #/while
        
        # Slice off the tail of the raw line.
        content = line.slice(il + iil, line.length)
        # Take off the raw line and replace it with a line that has
        # "- " turned into "  ".
        self.shift
        self.unshift(indent + body_indent + content)
        
        ret = parse_body(indent + body_indent)
        # Push whatever we got into the items
        li = Blocks::ListItem.new(list)
        li.blocks = ret
        items.push li
        
        # Then look for the next non-blank line.
        self.chomp_empty!
        break if @lines.empty?
      end
      
      list.items = items
      return list
    end
    
    # Consumes an entire sequence of bulleted list items.
    def handle_enumerated_list(line, indent)
      il = indent.length
      # /^(\s*)(\w+\.|\(?\w+\))(\s+)(.+)$/
      line.slice(il, line.length) =~ ENUMERATED_LIST_REGEX
      
      items = []
      list = Blocks::List.new(:enumerated)
      
      # Put the line back onto the queue with the indent
      self.unshift(line)
      # Looking at the latest raw line and making sure the line starts with
      # the indent we're expecting.
      while (line = self.peek) && # Latest line
            line.start_with?(indent) && # Enough existing indent
            line.slice(il, line.length) =~ ENUMERATED_LIST_REGEX
      #/while
        
        item_indent = $1 + $2 + $3
        body_indent = $1 + (" " * $2.length) + $3
        marker = $2
        content = $4
        
        # Take off the raw line and replace it with a line that has a plain
        # indent instead of one with the list item stuff.
        self.shift
        self.unshift(indent + body_indent + content)
        
        ret = parse_body(lines, indent + body_indent)
        # Push whatever we got into the items
        li = Blocks::ListItem.new(list)
        li.blocks = ret
        li.marker = marker
        items.push li
        
        # Then look for the next non-blank line.
        self.chomp_empty!(lines)
        break if lines.empty?
      end
      
      list.items = items
      return list
    end
    
    def handle_line_block(line, indent)
      # LINE_BLOCK_REGEX = /^(\s*)(\|\s+)(.+)$/
      line =~ LINE_BLOCK_REGEX
      
      content = $3
      line_indent = $1 || indent
      line_marker = $2
      # For continuations:
      line_blank_marker = line_marker.sub("|", " ")
      # For lines without proper indentation following the "|":
      line_simple_marker = "|"
      
      lines = [content]
      # Shortcuts
      lil = line_indent.length
      lml = line_marker.length
      # Consume lines and either grab the line if it has a marker/continuation
      # or end consumption upon reaching a blank line.
      line = self.replace_tabs(self.peek)
      while !line.nil? && line.start_with?(line_indent)
        # Slice off the indent
        line = line.slice(lil, line.length)
        # Check for markers
        if line.start_with?(line_marker)
          lines.push line.slice(lml, line.length)
        elsif line.start_with?(line_blank_marker)
          if line.strip.empty?
            # Hit an empty line
            break
          end
          # Continuation, so append it to the previous line
          lines.last << line.slice(lml, line.length)
        elsif line.strip == line_simple_marker
          # Blank line with simple marker (just "|" with no trailing space)
          lines.push("")
        else
          # Line didn't start with either of the correct markers
          if line.strip.empty?
            break
          else
            raise self.parse_error("Unrecognized line '#{line.inspect}' in line block")
          end
        end
        line = self.shift
      end
      
      return Blocks::Line.new(lines.join("\n"))
    end
    
    # Consumes one paragraph block.
    def handle_paragraph(line, indent)
      indent_length = indent.length
      
      content = [line.slice(indent_length, line.length)]
      
      # Checks if next line is valid and shifts it off if it is.
      next_line_okay = Proc.new {
        line = self.peek
        if line.strip.empty?
          next false
        end
        if !line.start_with? indent
          # If the indent doesn't match, then return all blocks.
          next false
        end
        self.shift
        true
      }
      
      while !@lines.empty? && next_line_okay.call
        content.push line.slice(indent_length, line.length)
      end
      
      if content.last.end_with? "::"
        # Push on an indicator for a literal block.
        self.unshift "#{indent}"
        self.unshift "#{indent}::"
      end
      
      return Blocks::Paragraph.new(content.join "\n")
    end
    
    def handle_transition(line, indent)
      return Blocks::Transition.new
    end
    
    def handle_wrapped_section_title(line, indent)
      prefix = line
      header = self.shift.slice(indent.length, line.length)
      suffix = self.shift.slice(indent.length, line.length)
      
      if prefix != suffix
        # TODO: Line numbers
        raise self.parse_error("Prefix doesn't match suffix")
      end
      return Blocks::Header.new(header)
    end
    
    def handle_plain_section_title(line, indent)
      header = line
      suffix = self.shift#.strip
      return Blocks::Header.new(header)
    end
    
    def handle_block_quote(line, indent)
      # /^(\s+)(.+)$/
      line =~ INDENTED_REGEX
      quote_indent = $1 # Includes *indent*
      content = $2
      
      # Set up the first line and slurp any following lines with sufficient
      # indentation.
      quote = [content]
      more = self.slurp(quote_indent)
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
    
    # Parses a literal code block (nearly identical to *handle_quote_block*).
    def handle_literal_block(line, indent)
      # /^(\s+)(.+)$/
      line =~ LITERAL_BLOCK_REGEX
      literal_indent = $1 # Does not include *indent*
      content = $2
      
      code = [content]
      more = self.slurp(indent + literal_indent)
      code.push(*more) if more
      
      return Blocks::Literal.new(code.join "\n")
    end
    
    # Parses a doctest by slurping up all non-blank lines at a specific
    # indentation level.
    def handle_doctest(line, indent)
      code = [line.slice(indent.length, line.length)]
      while (line = self.peek) && !line.strip.empty?
        code << line.slice(indent.length, line.length)
        lines.shift
      end
      # Check that the trailing line is empty and shift it or raise an error.
      if !line.nil?
        if line.strip.empty?
          lines.shift
        else
          raise self.parse_error("Expected trailing empty line")
        end
      end
      
      return Blocks::Doctest.new(code.join "\n")
    end
    
    def handle_explicit(line, indent)
      test_line = line.slice(indent.length, line.length)
      
      if test_line =~ DIRECTIVE_REGEX
        return handle_directive(test_line, indent)
      
      elsif test_line =~ FOOTNOTE_REFERENCE_REGEX
        return handle_footnote(test_line, indent)
      
      # Hyperlinks
      elsif test_line =~ ANONYMOUS_HYPERLINK_REFERENCE_REGEX
        # /^\.\. __\: (.+)/
        # TODO: Make this support the short-syntax ("__ http://www.python.org")
        target = $1
        @document.anonymous_references << $1
        return false
      elsif test_line =~ HYPERLINK_REFERENCE_REGEX
        # /^\.\. _(.+)\: (.+)/
        name = $1
        target = $2
        @document.references[name] = target
        return false
      else
        raise self.parse_error(
          "Don't know how to handle explicit line like: #{test_line.inspect}"
        )
      end
    end
    
    def handle_directive(test_line, indent)
      # DIRECTIVE_REGEX = /^\.\.\s+(.+)\:\:( .+)?/
      # DIRECTIVE_OPTION_REGEX = /^:(.+):\s+(.+)/
      test_line =~ DIRECTIVE_REGEX
      type = $1
      arguments = $2
      
      dir = Blocks::Explicit.new_for_params(type)
      dir.arguments = arguments
      
      first_line = self.peek
      # If there is nothing after the directive then just return it.
      if first_line.nil?
        return dir
      end
      
      # Calculates total indentation. Includes *indent*.
      def calculate_indent(line)
        # /^(\s+)(.+)$/
        line =~ INDENTED_REGEX
        return $1
      end
      
      # If it's not empty then it's going to be options.
      if !first_line.strip.empty?
        option_indent = calculate_indent(self.peek)
        
        line_okay = Proc.new {|l|
          if l.start_with? option_indent
            true
          else
            false
          end
        }
        # Search for any options
        while (line = self.peek) && line_okay.call(line)
          # Chop of the leading indent
          line = line.slice(option_indent.length, line.length)
          if line =~ DIRECTIVE_OPTION_REGEX
            dir.options[$1] = $2
            self.shift
          else
            break
          end
        end
      end
      
      # Eat up blank lines, then look for body content.
      self.chomp_empty!
      line = self.peek
      if line
        total_indent = calculate_indent(line)
        # If it was able to find indentation.
        if total_indent
          dir.blocks = self.parse_body(total_indent)
          # TODO: Maybe refactor this to be cleaner and less type-specific
          #       (instead more type-ducky).
          if dir.is_a? Blocks::Directives::Admonition
            if !dir.arguments.strip.empty?
              if dir.blocks.first.is_a?(Blocks::Paragraph)
                dir.blocks.first.text.prepend(dir.arguments.strip + "\n")
              else
                dir.blocks.unshift Blocks::Paragraph.new(dir.arguments.strip)
              end
              dir.arguments = ""
            end#/if args empty
          end#/if admonition
        
        end#/if total_indent
      end#/if line
      
      return dir
    end#/handle_directive
    
    def handle_footnote(test_line, indent)
      # /^\.\. \[(.+)\](.*)/
      test_line =~ FOOTNOTE_REFERENCE_REGEX
      label = $1
      content = $2.strip
      
      chomped = self.chomp_empty!
      # Calculate footnote indentation from the first line following it
      first_line = self.peek
      # /^(\s+)(.+)$/
      first_line =~ INDENTED_REGEX
      foot_indent = $1 # Includes *indent*
      
      # If no indented or lesser-indented content follows the footnote
      # directive then just return it.
      if foot_indent.nil? || foot_indent <= indent
        blocks = nil
        if !content.empty?
          blocks = [Blocks::Paragraph.new(content)]
        end
        return Blocks::Explicits::Footnote.new(label, blocks)
      end
      
      # There was some intented content so parse it.
      blocks = self.parse_body(foot_indent)
      
      if !content.empty?
        # If a paragraph immediately followed the footnote line then push the
        # content onto the front of that first paragraph block.
        if chomped == 0 && blocks.first.is_a?(Blocks::Paragraph)
          blocks.first.text.prepend(content + "\n")
        # Otherwise create a new paragraph and put it on the front.
        else
          blocks.unshift Blocks::Paragraph.new(content)
        end
      end
      
      return Blocks::Explicits::Footnote.new(label, blocks)
    end
    
    def handle_table(line, indent)
      # TABLE_REGEX = /^(\s*)(\+(?:-+\+)+)$/
      # TABLE_HEADER_REGEX = /^\+(?:=+\+)+$/
      # TABLE_ROW_REGEX    = /^\+(?:-+\+)+$/
      
      
      line =~ TABLE_REGEX
      table_indent = $1 || indent
      table_def = $2
      # "+--+--+" -> ["--", "--"]
      columns = table_def.scan(/-+/)
      # Lines of the table
      lines = []
      
      # Pull off all valid lines from input
      while (line = self.peek) &&
        line.start_with?(table_indent) && !line.strip.empty?
      #/while
        lines.push(line.slice(table_indent.length, line.length))
        
        self.shift
        
      end
      
      # Set up a sub-parser to parse table cells
      cell_parser = self.class.new_subparser(self)
      
      # Convert a row into an array of Blocks::TableCells using *parser*.
      def row_to_cells(parser, row, cells)
        cells.map do |cell|
          # Remove consistent indentation at the front of the cell body
          body = self.trim_indent(cell)
          # Parse the body into blocks
          blocks = parser.parse_thin(body)
          
          Blocks::TableCell.new(row, blocks)
        end
      end
      
      table_rows = []
      current_row = nil
      while !lines.empty?
        # Ensure there's always a row to work with
        unless current_row
          # Make row like ["", "", ...] if it's not set.
          current_row = []
          columns.length.times {|n| current_row.push "" }
        end
        # Current table line
        tl = lines[0]
        if tl =~ TABLE_HEADER_REGEX
          row = Blocks::TableHeader.new()
          row.cells = current_row # Table header cells are just strings
          table_rows << row
          
          current_row = nil
        elsif tl =~ TABLE_ROW_REGEX
          row = Blocks::TableRow.new()
          row.cells = row_to_cells(cell_parser, row, current_row)
          table_rows << row
          
          current_row = nil
        else
          # Regular row
          
          # Index within the row
          ri = 1 # Start past the initial "|"
          # Column index
          ci = 0
          columns.each do |col|
            # col like "----"
            r = tl.slice(ri, col.length)
            current_row[ci] << (r + "\n")
            
            ri += (col.length + 1)
            ci += 1
          end
        end
        lines.shift
      end
      
      table = Blocks::Table.new
      table.rows = table_rows
      return table
    end
    
    def handle_simple_table(line, indent)
      # SIMPLE_TABLE_REGEX = /^(\s*)(=+(?:\s+=+)*)/
      line =~ SIMPLE_TABLE_REGEX
      table_indent = $1 || indent
      table_def = $2
      
      # "==  ==" -> ["==", "  ", "=="]
      columns = table_def.rstrip.scan(/(?:=+)|(?:\s+)/)
      
      header_line = nil
      lines = []
      # Pull off valid lines from input in *lines*
      while (line = self.peek) && line.start_with?(table_indent)
        if line =~ SIMPLE_TABLE_REGEX
          next_line = self.peek_ahead(1)
          # If there's a following line
          if !next_line.nil? && !next_line.strip.empty?
            if lines.length == 1 # And there was a previous line
              header_line = lines.shift # Make that the header line
            elsif lines.length == 0
              self.shift
              break # Empty table
            else
              raise self.parse_error(
                "Too many lines in table header: #{lines.length.to_s}"
              )
            end
          # No following line, so end of table
          else
            self.shift
            break
          end
        else
          lines << line.slice(table_indent.length, line.length)
        end
        self.shift
      end#/while
      
      # Parses a row-string according to a columns array with
      # column-and-separator information.
      def parse_row(columns, row)
        if row.strip.empty?
          # If it's an empty row:
          cols = []
          # Columns like ["==", "  ", "=="], so an accurate count of content
          # columns is needed:
          column_count = (columns.length / 2) + 1
          column_count.times {|n| cols << "" }
          return cols
        end
        
        cols = []
        
        col = true # Whether it's a column or separator
        ri  = 0 # Character index in *row*
        i   = 0 # Array index in *columns*
        cl  = columns.length
        columns.each do |column|
          if col
            # It's a column
            if i == (cl - 1)
              # It's the last column so grab everything
              cols << row.slice(ri, row.length)
            else
              # Otherwise just grab inside that column
              cols << row.slice(ri, column.length).to_s
            end
          else
            # It's a separator so don't do anything.
          end
          i += 1
          ri += column.length
          col = !col
        end
        return cols
      end
      
      table_rows = []
      # Parse the raw lines using *parse_row()* and compact them into
      # row-column arrays in *table_rows*.
      current_row = nil
      while !lines.empty?
        tl = lines[0]
        if current_row.nil?
          current_row = parse_row(columns, tl)
          table_rows << current_row
        else
          # There is a current_row
          row = parse_row(columns, tl)
          if row[0].strip.empty?
            # Blank first column so append content of this row to the
            # current row.
            ci = 0
            row.each do |col|
              current_row[ci] << ("\n"+col)
              ci += 1
            end
          else
            # First column not blank so make a new row.
            current_row = row
            table_rows << current_row
          end
        end
        lines.shift
      end
      
      # Set up a sub-parser to parse table cells
      cell_parser = self.class.new_subparser(self)
      
      table_rows.map! do |row_array|
        row = Blocks::TableRow.new
        row.cells = row_array.map do |cell|
          if cell.strip == "\\"
            blocks = []
          else
            body   = self.trim_indent(cell)
            blocks = cell_parser.parse_thin(body)
          end
          Blocks::TableCell.new(row, blocks)
        end
        row#return
      end
      # If there is a header row then push it onto the front of the row array.
      if header_line
        header_row = Blocks::TableHeader.new
        header_row.cells = parse_row(columns, header_line)
        table_rows.unshift header_row
      end
      
      table = Blocks::Table.new
      table.rows = table_rows
      return table
    end
    
    # UTILITIES ---------------------------------------------------------------
    
    # Replace any leading tabs with 4 spaces
    def replace_tabs(line)
      line.gsub(/^\s*/) {|ws| ws.gsub("\t", "    ") }
    end
    
    # Basic manipulation of the line-queue:
    
    def shift
      @line_number += 1
      line = @lines.shift
      return line.nil? ? nil : self.replace_tabs(line)
    end
    def unshift(line)
      @line_number -= 1
      @lines.unshift line
    end
    
    # Looking at the line-queue:
    
    def peek
      @lines[0]
    end
    def peek_ahead(n)
      @lines[n]
    end
    
    # Advanced manipulation of the line-queue:
    
    # Eats up any empty lines it can but leave the most recent non-empty one
    # on the queue (unlike slurp_empty! which shifts it off and returns it).
    def chomp_empty!
      chomped = 0
      while !@lines.empty? && self.peek.strip.empty?
        chomped += 1
        self.shift
      end
      return chomped
    end
    
    # Consumes all empty lines it can and returns a non-blank line.
    def slurp_empty!
      while line = self.peek
        self.shift
        if line.strip.empty?
          next
        else
          return line
        end
      end
    end
    
    # Consumes lines at a given indentation level without regard for
    # sub-indentation (used for literal blocks and block quotes).
    def slurp(indent)
      indent_length = indent.length
      content = []
      while line = self.peek
        maybe = [] # Array of blank lines
        maybe_ahead = 0 # Count of blank lines; used with *self.peek_ahead*.
        # Indicates to the code after the loop whether or not to bail out of
        # the bigger while loop.
        do_break = false
        # If it hits a blank line it keeps peeking ahead for a line with the
        # right indentation level.
        if line.strip.empty?
          # Add the first empty line to the list of maybe lines.
          maybe_ahead += 1
          maybe << line.slice(indent_length, line.length)
          # Then start peeking ahead.
          while maybe_line = self.peek_ahead(maybe_ahead)
            if maybe_line.strip.empty?
              # If line empty:
              maybe_ahead += 1
              maybe << maybe_line.slice(indent_length, maybe_line.length)
              next
            elsif maybe_line.slice(0, indent_length) == indent
              # If line not empty with correct indentation.
              break
            else
              # Not empty with incorrect indentation; set *do_break* to tell
              # code after this while to bail out of the bigger while too.
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
          maybe.length.times { self.shift }
        end
        
        line = self.peek
        if !line.nil? && line.start_with?(indent)
          content << line.slice(indent_length, line.length)
          self.shift # Pull off this line
        else
          # Incorrect indentation
          break
        end
      end
      return content
    end
    
    # Removes leading indents from a body of text according to indent of the
    # first line in the body.
    def trim_indent(body)
      # TODO: Rewrite for speeeeed...
      lines = body.split("\n")
      if lines.empty?
        return body
      end
      
      first_line = lines[0]
      # /^(\s+)(.+)$/
      first_line =~ INDENTED_REGEX
      first_indent = $1
      if first_indent
        return lines.map! {|line|
          if line.start_with? first_indent
            line.slice(first_indent.length, line.length)
          else
            line
          end
        }.join("\n")
      else
        body
      end
    end
    
    # Error handling:
    
    def parse_error(message)
      ParseError.new(self, message)
    end
    
  end#/Parser3
end#/Burst
