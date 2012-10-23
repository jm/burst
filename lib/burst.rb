$:.unshift(File.dirname(__FILE__))

require 'burst/parser'
require 'burst/blocks/basic'
require 'burst/blocks/header'
require 'burst/blocks/transition'
require 'burst/blocks/paragraph'
require 'burst/blocks/list'
require 'burst/blocks/literal'
require 'burst/blocks/explicit'
require 'burst/blocks/block_quote'
require 'burst/blocks/doctest'

module Burst
  VERSION = '0.0.1'
end