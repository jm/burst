module Burst
  class ParseError < StandardError
    def initialize(parser, message)
      @parser  = parser
      @message = message
    end
    def message
      @message + " (near line #{@parser.line_number.to_s})"
    end
  end
  class RenderError < StandardError
  end
end
