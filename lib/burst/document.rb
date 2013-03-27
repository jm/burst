module Burst
  class Document
    attr_accessor :blocks, :references, :anonymous_references, :footnotes, :rendered

    def initialize(renderer)
      @blocks = []
      @footnotes = []

      @anonymous_references = []
      @references = {}

      @inline_renderer = renderer
    end

    def render
      @rendered = blocks.map {|e| e.to_html(@inline_renderer)}.join("\n")
      postprocess
    end

    def postprocess
      @rendered ||= render

      replace_reference_placeholders
      replace_anonymous_reference_placeholders

      @rendered
    end

    def replace_reference_placeholders
      @references.each do |reference, value|
        @rendered.gsub!(/\[\[hlr\:#{Digest::SHA1.hexdigest(reference)}\]\]/, value)
      end
    end

    def replace_anonymous_reference_placeholders
      @rendered.gsub!(/\[\[anon-hl\]\]/) do
        @anonymous_references.shift
      end
    end

    def generate_footnotes
      
    end
  end
end