require './lib/burst'

parser = Burst::Parser.new
parser.parse(File.read("./test.rst"))

parser.document.each {|e| puts e.to_html}