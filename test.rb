require './lib/burst'

parser = Burst::Parser3.new
puts parser.render(File.read("./test.rst"))
