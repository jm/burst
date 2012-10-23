require './lib/burst/inline_renderer'

r = Burst::InlineRenderer.new(File.read("./test_render.rst"))
r.render!

puts r.content