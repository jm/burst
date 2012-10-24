require './lib/burst'

parser = Burst::Parser.new
puts parser.render(File.read("./test.rst"))