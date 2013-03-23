require 'state_machine'

module Burst
  class Parser2
    attr_accessor :current_line, :document, :previous_blank
    
    SECTION_TITLE_REGEX = /^[\!\"\#\$\%\&\'\(\)\*\+\,\-\.\/\:\;\<\=\>\?\@\[\\\]\^\_\`\{\|\}\~]{1,}$/
    
    TRANSITION_REGEX = /^[\!\"\#\$\%\&\'\(\)\*\+\,\-\.\/\:\;\<\=\>\?\@\[\\\]\^\_\`\{\|\}\~]{4,}$/

    BULLET_LIST_REGEX = /^(\s*)([\*\+\-\•\‣])(\s+)(.+)$/

    EXPLICIT_REGEX = /^(\.\.\s+)(.+)$/

    LITERAL_BLOCK_START_REGEX = /^\:\:/

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
    
    
    attr_accessor :bullet_list
    attr_accessor :indent_level
    attr_accessor :indent_stack
    attr_accessor :block_quote
    def initialize_state_data
      @bullet_list = nil
      @indent_level = 0
      @indent_stack = []
      @block_quote = nil
    end
    def initialize(renderer = nil)
      @inline_renderer = (renderer || InlineRenderer.new)
      @block = nil
      initialize_state_data
      super()
    end
    
    def parse(content)
      @lines    = content.split("\n")
      @document = Document.new(@inline_renderer)
      
      while self.advance
        process_current_line
      end
      
      # puts document.inspect
      
      @document
    end
    def render(content)
      parse(content).render
    end
    
    def stack_pop
      item = self.indent_stack.pop
      parent = self.stack_head
      
      if parent.is_a? Blocks::List
        if item.is_a? Blocks::List
          # Push current onto the parent
          parent.elements << item
        elsif item.is_a? Blocks::BlockQuote
          block_quote = item
          parent.elements.last << block_quote
        else
          raise "Cannot pop #{item.class.to_s} onto list"
        end
      elsif parent.is_a? Blocks::Directive
        parent.blocks << item
      else
        raise "Don't know how to pop onto #{parent.class.to_s}"
      end
    end
    def stack_push(item)
      self.indent_stack.push item
    end
    def stack_head
      self.indent_stack.last
    end
    
    # Switch the state machine into the appropriate state to parse the head
    # of the stack (usually done after a stack_pop).
    def switch_to_stack_head
      head = self.stack_head
      if head.is_a? Blocks::List
        if head.type == :bullet
          self.parser = "bullet_list"
        else
          raise "Don't know how to switch to list type #{parent.type.to_s}"
        end
      else
        raise "Don't know how to switch to #{parser.stack_head.class.to_s}"
      end
    end
    
    def empty_stack
      while self.indent_stack.length >= 2
        self.stack_pop
      end
      if self.indent_stack.length == 1
        self.document.blocks << self.indent_stack.pop
      elsif self.indent_stack.length != 0
        raise "Unexpected stack size #{self.indent_stack.length.to_s}"
      end
    end
    
    state_machine :parser, :initial => :document, namespace: 'parse' do
      
      # Generic for indented line events
      event :indented_line do
        transition :bullet_list => same
        transition :block_quote => same
        transition :literal_block => same
        transition :directive => same
      end
      
      top_levels = [
        :document, :paragraph, :section_title, :transition, :directive
      ]
      
      # Empty the stack before transitioning to a top-level
      before_transition any => top_levels \
      do |parser, transition|
        next if parser.current_line.strip.empty?
        unless parser.current_line =~ /^\s+/
          parser.empty_stack
        end
      end
      
      # BULLET LIST -----------------------------------------------------------
      
      event :bullet_list do
        transition any => :bullet_list
      end
      
      after_transition any => :bullet_list, on: :bullet_list \
      do |parser, transition|
        parser.current_line =~ Parser2::BULLET_LIST_REGEX
        indent  = $1
        bullet  = $2
        space   = $3
        content = $4
        total_indent = indent.length + bullet.length + space.length
        
        if total_indent > parser.indent_level
          parser.stack_push(Blocks::List.new(:bullet, nil))
        elsif total_indent < parser.indent_level
          parser.stack_pop
        else# total_indent == parser.indent_level
          # pass
        end
        
        parser.stack_head.elements << [Blocks::Paragraph.new(content)]
        parser.indent_level = total_indent # Update the indent level
      end
      after_transition :bullet_list => :bullet_list, on: :indented_line \
      do |parser, transition|
        parser.current_line =~ Parser2::INDENTED_REGEX
        
        indent = $1
        content = $2
        
        total_indent = indent.length
        if total_indent == parser.indent_level
          if parser.previous_blank
            # Add a new paragraph sub-element
            parser.stack_head.elements.last << Blocks::Paragraph.new(content)
          else
            # Append text to last sub-element
            parser.stack_head.elements.last.last.text << ("\n"+content)
          end
        elsif total_indent > parser.indent_level
          parser.block_quote_parse
        end
      end
      
      
      # TRANSITION ------------------------------------------------------------
      
      event :transition do
        transition (any - :transition) => :transition
      end
      
      after_transition (any - :transition) => :transition \
      do |parser, transition|
        parser.document.blocks << Blocks::Transition.new
        parser.indent_level = 0
      end
      
      # SECTION TITLE ---------------------------------------------------------
      
      event :section_title do
        transition any => :section_title
      end
      
      after_transition any => :section_title \
      do |parser, transition|
        parser.document.blocks << Blocks::Header.new(parser.current_line)
        parser.indent_level = 0
      end
      
      # BLOCK QUOTE -----------------------------------------------------------
      
      event :block_quote do
        transition :bullet_list => :block_quote
      end
      
      after_transition (any - :block_quote) => :block_quote \
      do |parser, transition|
        parser.current_line =~ Parser2::INDENTED_REGEX
        
        indent = $1
        content = $2
        
        parser.stack_push Blocks::BlockQuote.new(content)
        parser.indent_level = indent.length
      end
      after_transition :block_quote => :block_quote do |parser, transition|
        parser.current_line =~ Parser2::INDENTED_REGEX
        
        indent = $1
        content = $2
        
        switch_to_parent = Proc.new {
          parser.stack_pop
          parser.switch_to_stack_head
          parser.process_current_line
        }
        
        total_indent = indent.length
        # TODO: Make blockquotes store paragraphs instead of raw text.
        if total_indent == parser.indent_level
          if parser.current_line =~ QUOTE_ATTRIBUTION_REGEX
            attribution_symbol = $1
            attribution = $2
            # Add the attribution
            parser.stack_head.attribution = attribution
            # Leave the block quote
            switch_to_parent.call
          else
            parser.stack_head.text << ("\n"+content)
          end
        elsif total_indent < parser.indent_level
          parser.indent_level = total_indent
          switch_to_parent.call
        else
          raise "Can't do this yet (inner blockquote)"
        end
      end
      
      # PARAGRAPH -------------------------------------------------------------
      
      after_transition any => :paragraph do |parser, transition|
        content = parser.current_line
        if !parser.previous_blank && \
           parser.document.blocks.last.is_a?(Blocks::Paragraph)
        #/if
          # Append text to last paragraph
          parser.document.blocks.last.text << ("\n"+content)
        else
          parser.document.blocks << Blocks::Paragraph.new(content)
        end
        # If it ends with a "::" then switch to the literal block state.
        if parser.current_line.strip.end_with? "::"
          parser.parser = "literal_block"
        end
        parser.indent_level = 0
      end
      
      event :paragraph do
        transition any => :paragraph
      end
      
      # LITERAL BLOCK ---------------------------------------------------------
      
      event :literal_block do
        transition any => :literal_block
      end
      after_transition any => :literal_block \
      do |parser, transition|
        content = parser.current_line
        
        is_previous_block = (parser.document.blocks.last.is_a? Blocks::Literal)
        
        # If it's a blank line
        content_stripped = content.strip
        if content_stripped.empty?
          # If currently in a literal then just throw on a newline
          if is_previous_block
            parser.document.blocks.last.content << ("\n"+content)
          else
            next
          end
        end
        
        if is_previous_block
          # Remove leading indents
          content = content.sub(/^\s{#{parser.indent_level.to_s}}/, '')
          parser.document.blocks.last.content << ("\n"+content)
        else
          parser.current_line =~ Parser2::INDENTED_REGEX
        
          indent = $1
          content = $2
          
          parser.indent_level = indent.length
          parser.document.blocks << Blocks::Literal.new(content)
        end
      end
      
      # DIRECTIVE -------------------------------------------------------------
      
      event :directive do
        transition any => :directive
      end
      
      # Entering a directive
      after_transition any => :directive, on: :directive \
      do |parser, transition|
        meta = {}
        if parser.current_line =~ FOOTNOTE_REFERENCE_REGEX
          type = "footnote"
          reference = $1
          arguments = $2.strip
          meta = {:reference => reference}
        else
          parser.current_line =~ DIRECTIVE_REGEX
          type = $1
          arguments = $2.to_s.lstrip
          # explicit = Blocks::Explicit.new_for_params(type, arguments)
        end
        directive = Blocks::Directive.new(type)
        directive.arguments = arguments
        directive.meta = meta
        # Directives must be top-level
        parser.empty_stack
        parser.stack_push directive
        parser.indent_level = -1
      end
      # Inside a directive (indented lines)
      after_transition :directive => :directive, on: :indented_line \
      do |parser, transition|
        # Ignore empty lines
        if parser.current_line.strip.empty?
          next
        end
        
        parser.current_line =~ Parser2::INDENTED_REGEX
        indent = $1
        content = $2
        # Set or check the indent
        if parser.indent_level == -1
          parser.indent_level = indent.length
        elsif indent.length != parser.indent_level
          raise "Invalid indent #{indent.length.to_s} (expected #{parser.indent_level.to_s})"
        end
        
        directive = parser.stack_head
        
        # Check for options
        if directive.blocks.empty? && content =~ Parser2::DIRECTIVE_OPTION_REGEX
          # No content and matches option syntax
          opt = $1
          val = $2
          directive.options[opt] = val
          next
        end
        
        # Parsing the body of the directive:
        
        # Simple paragraph parsing
        # TODO: Make it handle literal blocks
        if !parser.previous_blank && \
           directive.blocks.last.is_a?(Blocks::Paragraph)
        #/if
          # Append text to last paragraph
          directive.blocks.last.text << ("\n"+content)
        else
          directive.blocks << Blocks::Paragraph.new(content)
        end
        
        # TODO: Make this handle other stuff besides paragraphs.
      end
      
      
      
      
      
      
      
      
      state :section_title
      state :section_title_inside
      state :document
      state :paragraph
      state :bullet_list
      state :enumerated_list
      state :definition_list
      state :field_list
      state :option_list
      state :literal_block
      state :line_block
      state :block_quote
      state :doctest_block
      state :table
      state :directive
      
    end
    
    def line_ahead(index)
      @lines[index]
    end
    def advance
      line = @lines.shift
      return false unless line
      
      @previous_line = @current_line
      
      @current_line = line.rstrip
    end
    
    
    def process_current_line
      if current_line.empty?
        @previous_blank = true
      elsif current_line =~ BULLET_LIST_REGEX
        bullet_list_parse
      elsif current_line =~ INDENTED_REGEX
        indented_line_parse
      elsif current_line =~ SECTION_TITLE_REGEX
        # Wrapped header or transition line
        if current_line =~ TRANSITION_REGEX && \
           (line_ahead(0).strip.empty? && @previous_blank)
          # It was a transition (like "\n----------\n\n")
          transition_parse
        else
          # Wrapped header
          return
        end
      elsif line_ahead(0) =~ SECTION_TITLE_REGEX
        section_title_parse
        self.advance # Advance onto the wrapping line
        self.advance # Then beyond the wrapping line
      elsif current_line =~ DIRECTIVE_REGEX
        directive_parse
      else
        paragraph_parse
      end
      
      @previous_blank = false unless current_line.empty?
      
    end
    
  end
end

