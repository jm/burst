require './lib/burst'

parser = Burst::NewParser.new
puts parser.render(File.read("./test2.rst"))
