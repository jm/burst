require 'state_machine'

module Burst
  class Parser2
    attr_accessor :current_line
    
    # TODO: Unescape as much as possible
    SECTION_HEADER_REGEX = /^[\!\"\#\$\%\&\'\(\)\*\+\,\-\.\/\:\;\<\=\>\?\@\[\\\]\^\_\`\{\|\}\~]{4,}$/

    BULLET_LIST_REGEX = /^([\*\+\-\•\‣]) (.+)/

    EXPLICIT_REGEX = /^\.\. .+/

    LITERAL_BLOCK_START_REGEX = /^\:\:/

    LITERAL_BLOCK_REGEX = /^\s.+/

    QUOTE_LITERAL_BLOCK_REGEX = /^\s*\".+/

    QUOTE_ATTRIBUTION_REGEX = /^\s*(--|---|-) (.+)/

    DOCTEST_BLOCK_REGEX = /^\>\>\> .+/

    # TODO: Unescape as much as possible
    QUOTED_LITERAL_REGEX = /^[\!\"\#\$\%\&\'\(\)\*\+\,\-\.\/\:\;\<\=\>\?\@\[\\\]\^\_\`\{\|\}\~]{1,} $/

    ENUMERATED_LIST_REGEX = /^(\w+\.|\(?\w+\)) (.+)/

    # Explicit markup blocks
    FOOTNOTE_REFERENCE_REGEX = /^\.\. \[(.+)\] (.*)/

    ANONYMOUS_HYPERLINK_REFERENCE_REGEX = /^\.\. __\: (.+)/
    
    HYPERLINK_REFERENCE_REGEX = /^\.\. _(.+)\: (.+)/
    
    DIRECTIVE_REGEX = /^\.\. (.+)\:\: (.+)/
    
    
    attr_accessor :bullet_list
    def initialize_state_data
      @bullet_list = nil
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
      
      while (line = @lines.shift)
        @current_line = line
        process_current_line
      end
      
      @document
    end
    def render(content)
      parse(content)#.render
      ''
    end
    
    state_machine :parser, :initial => :document, namespace: 'parse' do
      after_transition :document => :bullet_list do |parser, transition|
        parser.bullet_list = Blocks::List.new(:bullet, [parser.current_line])
      end
      
      event :bullet_list do
        transition :bullet_list => same, :document => :bullet_list
      end
      
      state :document do
        
      end
      state :paragraph do
        
      end
      
      
      state :bullet_list do
        
      end
      
      
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
    
    
    def process_current_line
      
      if current_line.empty?
        nil
        
      elsif current_line =~ BULLET_LIST_REGEX
        bullet_list_parse
      elsif
        puts "Don't know how to handle: #{current_line.inspect}"
      end
    end
    
  end
end

