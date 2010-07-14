require File.dirname(__FILE__) + "/test_helper"

class IndenterTest < Test::Unit::TestCase
  def setup 
    @sf = Eden::SourceFile.new( "dummy.rb" )
  end

  def test_should_not_indent_when_not_configured
    Indenter.configure do |i|
      i.adjust_indents false
    end

    @sf.stubs(:source).returns("def function\nreturn nil\nend\n")
    @sf.tokenize!
    Indenter.format( @sf )
    assert_equal "def function\n", @sf.lines[0].joined_tokens
    assert_equal "return nil\n", @sf.lines[1].joined_tokens
    assert_equal "end\n", @sf.lines[2].joined_tokens

    Indenter.configure do |i|
      i.adjust_indents true
    end
  end

  def test_should_use_correct_indent_character_when_indenting
    Indenter.configure do |i|
      i.indent_character "\t"
      i.indent_characters_per_step 1
    end

    @sf.stubs(:source).returns("def function\nreturn nil\nend\n")
    @sf.tokenize!
    Indenter.format( @sf )
    assert_equal "def function\n", @sf.lines[0].joined_tokens
    assert_equal "\treturn nil\n", @sf.lines[1].joined_tokens
    assert_equal "end\n", @sf.lines[2].joined_tokens

    Indenter.configure do |i|
      i.indent_character " "
      i.indent_characters_per_step 2
    end
  end

  def test_should_indent_function_body
    @sf.stubs(:source).returns("def function\nreturn nil\nend\n")
    @sf.tokenize!
    Indenter.format( @sf )
    assert_equal "def function\n", @sf.lines[0].joined_tokens
    assert_equal "  return nil\n", @sf.lines[1].joined_tokens
    assert_equal "end\n", @sf.lines[2].joined_tokens
  end

  def test_should_indent_class_body
    @sf.stubs(:source).returns("class Test\ndef blah\nreturn nil\nend\nend\n")
    @sf.tokenize!
    Indenter.format( @sf )
    assert_equal "class Test\n", @sf.lines[0].joined_tokens
    assert_equal "  def blah\n", @sf.lines[1].joined_tokens
    assert_equal "    return nil\n", @sf.lines[2].joined_tokens
    assert_equal "  end\n", @sf.lines[3].joined_tokens
    assert_equal "end\n", @sf.lines[4].joined_tokens
  end

  def test_should_indent_module_body
    @sf.stubs(:source).returns("module Test\ndef blah\nreturn nil\nend\nend\n")
    @sf.tokenize!
    Indenter.format( @sf )
    assert_equal "module Test\n", @sf.lines[0].joined_tokens
    assert_equal "  def blah\n", @sf.lines[1].joined_tokens
    assert_equal "    return nil\n", @sf.lines[2].joined_tokens
    assert_equal "  end\n", @sf.lines[3].joined_tokens
    assert_equal "end\n", @sf.lines[4].joined_tokens
  end

  def test_should_not_indent_one_line_class
    @sf.stubs(:source).returns("class Test; end\nclass Test2; end\n")
    @sf.tokenize!
    Indenter.format( @sf )
    assert_equal "class Test; end\n", @sf.lines[0].joined_tokens
    assert_equal "class Test2; end\n", @sf.lines[1].joined_tokens
  end

  def test_should_indent_class_to_self_block
    # Note: Each line here has six spaces of indent before it, so this
    # tests the logic in adjust_indent where there is an existing whitespace
    # token at the start of the line
    @sf.stubs(:source).returns(<<-SOURCE)
      class Test
      class << self
      def function
      return nil
      end
      end
      end
    SOURCE
    @sf.tokenize!
    Indenter.format( @sf )
    assert_equal "class Test\n", @sf.lines[0].joined_tokens
    assert_equal "  class << self\n", @sf.lines[1].joined_tokens
    assert_equal "    def function\n", @sf.lines[2].joined_tokens
    assert_equal "      return nil\n", @sf.lines[3].joined_tokens
    assert_equal "    end\n", @sf.lines[4].joined_tokens
    assert_equal "  end\n", @sf.lines[5].joined_tokens
    assert_equal "end\n", @sf.lines[6].joined_tokens
  end

  def test_should_indent_block
    @sf.stubs(:source).returns("@item.map do |i|\ni*2\nend\n")
    @sf.tokenize!
    Indenter.format( @sf )
    assert_equal "@item.map do |i|\n", @sf.lines[0].joined_tokens
    assert_equal "  i*2\n", @sf.lines[1].joined_tokens
    assert_equal "end\n", @sf.lines[2].joined_tokens
  end

  def test_should_indent_begin_rescue_block
    @sf.stubs(:source).returns("def function\nbegin\nHttp.get\nrescue\nHttp.post\nend\nend\n")
    @sf.tokenize!
    Indenter.format( @sf )
    assert_equal "def function\n", @sf.lines[0].joined_tokens
    assert_equal "  begin\n", @sf.lines[1].joined_tokens
    assert_equal "    Http.get\n", @sf.lines[2].joined_tokens
    assert_equal "  rescue\n", @sf.lines[3].joined_tokens
    assert_equal "    Http.post\n", @sf.lines[4].joined_tokens
    assert_equal "  end\n", @sf.lines[5].joined_tokens
    assert_equal "end\n", @sf.lines[6].joined_tokens
  end

  def test_should_indent_if_else_block
    @sf.stubs(:source).returns(<<-SOURCE.gsub(/^      /, ''))
      if @something
      do_something
      elsif @something_else
      do_nothing
      else
      do_something_else
      end
    SOURCE
    @sf.tokenize!
    Indenter.format( @sf )
    assert_equal "if @something\n", @sf.lines[0].joined_tokens
    assert_equal "  do_something\n", @sf.lines[1].joined_tokens
    assert_equal "elsif @something_else\n", @sf.lines[2].joined_tokens
    assert_equal "  do_nothing\n", @sf.lines[3].joined_tokens
    assert_equal "else\n", @sf.lines[4].joined_tokens
    assert_equal "  do_something_else\n", @sf.lines[5].joined_tokens
    assert_equal "end\n", @sf.lines[6].joined_tokens
  end

  def test_should_indent_case_statement_when_not_set
    @sf.stubs(:source).returns(<<-SOURCE.gsub(/^      /, ''))
      case @something
      when :this
      do_this
      when :that
      do_that
      else
      do_the_other
      end
SOURCE
    @sf.tokenize!
    Indenter.format( @sf )
    assert_equal "case @something\n", @sf.lines[0].joined_tokens
    assert_equal "when :this\n", @sf.lines[1].joined_tokens
    assert_equal "  do_this\n", @sf.lines[2].joined_tokens
    assert_equal "when :that\n", @sf.lines[3].joined_tokens
    assert_equal "  do_that\n", @sf.lines[4].joined_tokens
    assert_equal "else\n", @sf.lines[5].joined_tokens
    assert_equal "  do_the_other\n", @sf.lines[6].joined_tokens
    assert_equal "end\n", @sf.lines[7].joined_tokens
  end

  def test_should_indent_while_statement
    @sf.stubs(:source).returns(<<-SOURCE.gsub(/^      /, ''))
      while @something
      do_something
      end
SOURCE
    @sf.tokenize!
    Indenter.format( @sf )
    assert_equal "while @something\n", @sf.lines[0].joined_tokens
    assert_equal "  do_something\n", @sf.lines[1].joined_tokens
    assert_equal "end\n", @sf.lines[2].joined_tokens
  end
end
