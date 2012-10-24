module Burst
  class Document
    attr_accessor :blocks, :references, :directives, :anonymous_hyperlinks, :footnotes, :rendered

    def initialize(renderer)
      @blocks = []
      @anonymous_hyperlinks = []
      @footnotes = []

      @references = {}
      @directives = {}

      @inline_renderer = renderer
    end
  end
end