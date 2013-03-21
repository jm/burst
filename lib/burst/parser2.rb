require 'state_machine'

module Burst
  class Parser2
    attr_accessor :current_line, :document, :previous_blank
    
    SECTION_TITLE_REGEX = /^[\!\"\#\$\%\&\'\(\)\*\+\,\-\.\/\:\;\<\=\>\?\@\[\\\]\^\_\`\{\|\}\~]{1,}$/

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
    
    DIRECTIVE_REGEX = /^\.\. (.+)\:\: (.+)/
    
    
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
      
      puts document.inspect
      
      @document
    end
    def render(content)
      parse(content).render
    end
    
    def stack_pop
      puts self.indent_stack.inspect
      
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
    
    def empty_stack
      while self.indent_stack.length >= 2
        self.stack_pop
      end
      self.document.blocks << self.indent_stack.pop
    end
    
    state_machine :parser, :initial => :document, namespace: 'parse' do
      
      # BULLET LIST -----------------------------------------------------------
      
      # Entering/inside
      event :bullet_list do
        transition any => :bullet_list
      end
      event :indented_line do
        transition :bullet_list => same
        transition :block_quote => same
      end
      
      after_transition any => :bullet_list,
      on: :bullet_list do |parser, transition|
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
        puts parser.current_line.inspect
        parser.current_line =~ Parser2::INDENTED_REGEX
        
        indent = $1
        content = $2
        
        puts "ti: #{indent.length.to_s}"
        puts "pi: #{parser.indent_level.to_s}"
        
        total_indent = indent.length
        if total_indent == parser.indent_level
          puts 'there'
          parser.stack_head.elements.last << Blocks::Paragraph.new(content)
        elsif total_indent > parser.indent_level
          parser.block_quote_parse
        end
      end
      after_transition :bullet_list => [:document, :paragraph, :section_title] \
      do |parser, transition|
        unless parser.current_line =~ /^\s+/
          parser.empty_stack
        end
      end
      
      
      # SECTION TITLE ---------------------------------------------------------
      
      after_transition any => :section_title \
      do |parser, transition|
        parser.document.blocks << Blocks::Header.new(parser.current_line)
        parser.indent_level = 0
      end
      
      event :section_title do
        transition any => :section_title
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
        
        total_indent = indent.length
        
        if total_indent == parser.indent_level
          parser.stack_head.text << content
          parser.indent_level = total_indent
        elsif total_indent < parser.indent_level
          parser.stack_pop
          parser.indent_level = total_indent
          
          # Call our parent's :indented_line handler instead of our own.
          parent = parser.stack_head
          if parent.is_a? Blocks::List
            if parent.type == :bullet
              parser.parser = "bullet_list"
            else
              raise "Don't know how to transition into list type #{parent.type.to_s}"
            end
          else
            raise "Don't know how to transition into #{parser.stack_head.class.to_s}"
          end
          parser.indented_line_parse
          
        else
          raise "Can't do this yet"
        end
      end
      
      
      
      # PARAGRAPH -------------------------------------------------------------
      
      after_transition any => :paragraph do |parser, transition|
        parser.indent_level = 0
      end
      
      event :paragraph do
        transition :bullet_list => :paragraph
        transition :section_title => :paragraph
      end
      
      
      
      
      
      
      
      
      
      
      
      
      state :section_title
      state :section_title_inside
      state :document
      state :paragraph
      state :bullet_list
      
      
      state :enumerated_list do
        
      end
      state :definition_list do
        
      end
      state :field_list do
        
      end
      state :option_list do
        
      end
      state :literal_block do
        
      end
      state :line_block do
        
      end
      state :block_quote do
        
      end
      state :doctest_block do
        
      end
      state :table do
        
      end
      state :directive do
        
      end
      
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
        # Look ahead for wrapped section titles
        wrapped = (line_ahead(1) =~ SECTION_TITLE_REGEX)
        if wrapped
          self.advance
        # It was the previous line was the header
        else
          @current_line = @previous_line
        end
        section_title_parse
        if wrapped
          self.advance # Move beyond the current line
          self.advance # Then beyond the following wrapping line
        end
      elsif
        paragraph_parse
      end
      
      @previous_blank = false unless current_line.empty?
      
    end
    
  end
end

