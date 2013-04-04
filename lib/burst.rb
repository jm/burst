$:.unshift(File.dirname(__FILE__))

require 'burst/exception'
require 'burst/parser'
require 'burst/document'
require 'burst/inline_renderer'

require 'burst/blocks/basic'
require 'burst/blocks/header'
require 'burst/blocks/transition'
require 'burst/blocks/paragraph'
require 'burst/blocks/list'
require 'burst/blocks/literal'
require 'burst/blocks/block_quote'
require 'burst/blocks/doctest'
require 'burst/blocks/directive'
require 'burst/blocks/directives/admonition'
require 'burst/blocks/directives/figure'
require 'burst/blocks/directives/image'
require 'burst/blocks/directives/topic'
require 'burst/blocks/directives/code'
require 'burst/blocks/directives/function'
require 'burst/blocks/explicit'
require 'burst/blocks/explicits/footnote'
require 'burst/blocks/table'
require 'burst/blocks/line'

module Burst
  VERSION = '0.0.1'
end
