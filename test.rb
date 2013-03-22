require './lib/burst'

parser = Burst::Parser2.new
puts parser.render(File.read("./test.rst"))
