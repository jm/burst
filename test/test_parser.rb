require File.expand_path('../test_helper', __FILE__)

class TestParser < MiniTest::Unit::TestCase
  def setup
    # filepath = File.join(File.dirname(__FILE__), 'test_parser_doc.rst')
    # @doc = Burst::Parser.new.parse(File.read(filepath))
    @parser = Burst::Parser.new
  end
  
  def test_wrapped_header
    header = @parser.parse("=\nA\n=").blocks.first
    assert_kind_of Burst::Blocks::Header, header
  end
  def test_simple_header
    header = @parser.parse("A\n=").blocks.first
    assert_kind_of Burst::Blocks::Header, header
  end
end
