require './lib/burst/inline_renderer'

r = Burst::InlineRenderer.new
z = r.render(File.read("./test_render.rst"))

puts z