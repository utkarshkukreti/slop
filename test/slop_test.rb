require File.dirname(__FILE__) + '/helper'

class SlopTest < TestCase
  def clean_options(*args)
    Slop.new.send(:clean_options, args)
  end

  def temp_argv(items)
    old_argv = ARGV.clone
    ARGV.replace items
    yield
  ensure
    ARGV.replace old_argv
  end

  test 'includes Enumerable' do
    assert Slop.included_modules.include?(Enumerable)
  end

  test 'new accepts a hash or array of symbols' do
    slop = Slop.new :strict, :multiple_switches => true
    [ :@multiple_switches, :@strict ].each do |var|
      assert slop.instance_variable_get var
    end
  end

  test 'parse returns a Slop object' do
    slop = Slop.parse([])
    assert_kind_of Slop, slop
  end

  test 'enumerating options' do
    slop = Slop.new
    slop.opt(:f, :foo, 'foo')
    slop.opt(:b, :bar, 'bar')

    slop.each { |option| assert_kind_of Slop::Option, option }
  end

  test 'defaulting to ARGV' do
    temp_argv(%w/--name lee/) do
      assert_equal('lee', Slop.parse { on :name, true }[:name])
    end
  end

  test 'callback when option array is empty' do
    item1 = nil
    temp_argv([]) do
      Slop.new { on_empty { item1 = 'foo' } }.parse
    end

    assert_equal 'foo', item1
  end

  test 'multiple switches with the :multiple_switches flag' do
    slop = Slop.new :multiple_switches => true, :strict => true
    %w/a b c/.each { |f| slop.on f }
    slop.on :z, true
    slop.parse %w/-abc/

    %w/a b c/.each do |flag|
      assert slop[flag]
      assert slop.send(flag + '?')
    end

    assert_raises(Slop::InvalidOptionError, /d/)   { slop.parse %w/-abcd/ }
    assert_raises(Slop::MissingArgumentError, /z/) { slop.parse %w/-abcz/ }
  end

  test 'passing a block' do
    assert Slop.new {}
    slop = nil
    assert Slop.new {|s| slop = s }
    assert_kind_of Slop, slop
  end

  test 'automatically adding the help option' do
    slop = Slop.new
    assert_empty slop.options

    slop = Slop.new :help => true
    refute_empty slop.options
    assert_equal 'Print this help message', slop.options[:help].description
  end

  test 'yielding non-options when a block is passed to "parse"' do
    opts = Slop.new do
      on :name, true
    end
    opts.parse(%w/--name lee a/) do |v|
      assert_equal 'a', v
    end
  end

  test 'preserving order when yielding non-options' do
    items = []
    slop = Slop.new { on(:name, true) { |name| items << name } }
    slop.parse(%w/foo --name bar baz/) { |value| items << value }
    assert_equal %w/foo bar baz/, items
  end

  test 'setting the banner' do
    slop = Slop.new
    slop.banner = "foo bar"

    assert_equal "foo bar", slop.banner
    assert slop.to_s =~ /^foo bar/

    slop.banner = nil
    assert_equal "", slop.to_s

    slop = Slop.new "foo bar"
    assert_equal "foo bar", slop.banner

    slop = Slop.new :banner => "foo bar"
    assert_equal "foo bar", slop.banner
  end

  test 'storing long option lengths' do
    slop = Slop.new
    assert_equal 0, slop.longest_flag
    slop.opt(:name)
    assert_equal 4, slop.longest_flag
    slop.opt(:username)
    assert_equal 8, slop.longest_flag
  end

  test 'parse returning the list of arguments left after parsing' do
    opts = Slop.new do
      on :name, true
    end
    assert_equal %w/a/, opts.parse!(%w/--name lee a/)
    assert_equal %w/--name lee a/, opts.parse(%w/--name lee a/)
  end

  test '#parse does not remove parsed items' do
    items = %w/--foo/
    Slop.new { |opt| opt.on :foo }.parse(items)
    assert_equal %w/--foo/, items
  end

  test '#parse! removes parsed items' do
    items = %w/--foo/
    Slop.new { |opt| opt.on :foo }.parse!(items)
    assert_empty items
  end

  test '#parse! removes parsed items prefixed with --no-' do
    items = %w/--no-foo/
    Slop.new { |opt| opt.on :foo }.parse!(items)
    assert_empty items
  end

  test 'the shit out of clean_options' do
    assert_equal(
      ['s', 'short', 'short option', false],
      clean_options('-s', '--short', 'short option')
    )

    assert_equal(
      [nil, 'long', 'long option only', true],
      clean_options('--long', 'long option only', true)
    )

    assert_equal(
      ['S', 'symbol', 'symbolize', false],
      clean_options(:S, :symbol, 'symbolize')
    )

    assert_equal(
      ['a', nil, 'alphabetical only', true],
      clean_options('a', 'alphabetical only', true)
    )

    assert_equal( # for description-less options
      [nil, 'optiononly', nil, false],
      clean_options('--optiononly')
    )

    assert_equal(['c', nil, nil, true], clean_options(:c, true))
    assert_equal(['c', nil, nil, false], clean_options(:c, false))
  end

  test '[] returns an options argument value or a command or nil (in that order)' do
    slop = Slop.new
    slop.opt :n, :name, true
    slop.opt :foo
    slop.command(:foo) { }
    slop.command(:bar) { }
    slop.parse %w/--name lee --foo/

    assert_equal 'lee', slop[:name]
    assert_equal 'lee', slop[:n]

    assert_equal true, slop[:foo]
    assert_kind_of Slop, slop[:bar]

    assert_nil slop[:baz]
  end

  test 'arguments ending ? test for option existance' do
    slop = Slop.new
    slop.opt :v, :verbose
    slop.opt :d, :debug
    slop.parse %w/--verbose/

    assert slop[:verbose]
    assert slop.verbose?

    refute slop[:debug]
    refute slop.debug?
  end

  test 'options are present' do
    opts = Slop.new { on :f, 'foo-bar'; on :b, 'bar-baz' }
    opts.parse %w/--foo-bar/

    assert opts.present?('foo-bar')
    refute opts.present?('bar-baz')
  end

  test 'raises if an option expects an argument and none is given' do
    slop = Slop.new
    slop.opt :name, true
    slop.opt :age, :optional => true

    assert_raises(Slop::MissingArgumentError, /name/) { slop.parse %w/--name/ }
    assert slop.parse %w/--name 'foo'/
  end

  test 'returning a hash of options' do
    slop = Slop.new
    slop.opt :name, true
    slop.opt :version
    slop.opt :V, :verbose, :default => false
    slop.parse %w/--name lee --version/

    assert_equal({'name' => 'lee', 'version' => true, 'verbose' => false}, slop.to_hash)
    assert_equal({:name => 'lee', :version => true, :verbose => false}, slop.to_hash(true))
  end

  test 'iterating options' do
    slop = Slop.new
    slop.opt :a, :abc
    slop.opt :f, :foo

    assert_equal 2, slop.count
    slop.each {|opt| assert_kind_of Slop::Option, opt }
  end

  test 'fetching options and option values' do
    slop = Slop.new
    slop.opt :foo, true
    slop.parse %w/--foo bar/

    assert_kind_of Slop::Option, slop.options[:foo]
    assert_equal "bar", slop[:foo]
    assert_equal "bar", slop['foo']
    assert_kind_of Slop::Option, slop.options[0]
    assert_nil slop.options['0']
  end

  test 'printing help' do
    slop = Slop.new
    slop.banner = 'Usage: foo [options]'
    slop.parse
    assert slop.to_s =~ /^Usage: foo/
  end

  test 'passing argument values to blocks' do
    name = nil
    opts = Slop.new
    opts.on :name, true, :callback => proc {|n| name = n}
    opts.parse %w/--name lee/
    assert_equal 'lee', name
  end

  test 'strict mode' do
    strict = Slop.new :strict => true
    totallynotstrict = Slop.new

    assert_raises(Slop::InvalidOptionError, /--foo/) { strict.parse %w/--foo/ }
    assert totallynotstrict.parse %w/--foo/
  end

  test 'strict mode parses options before raising Slop::InvalidOptionError' do
    strict = Slop.new :strict => true
    strict.opt :n, :name, true

    assert_raises(Slop::InvalidOptionError, /--foo/) { strict.parse %w/--foo --name nelson/ }
    assert_equal 'nelson', strict[:name]
  end

  test 'short option flag with no space between flag and argument' do
    slop = Slop.new
    slop.opt :p, :password, true
    slop.opt :s, :shortpass, true
    slop.parse %w/-p foo -sbar/

    assert_equal 'foo', slop[:password]
    assert_equal 'bar', slop[:shortpass]
  end

  test 'prefixing --no- onto options for a negative result' do
    slop = Slop.new
    slop.opt :d, :debug
    slop.opt :v, :verbose, :default => true
    slop.parse %w/--no-debug --no-verbose --no-nothing/

    refute slop.verbose?
    refute slop.debug?
    refute slop[:verbose]
    refute slop[:debug]
  end

  test 'option=value' do
    slop = Slop.new
    slop.opt :n, :name, true
    slop.parse %w/--name=lee/

    assert_equal 'lee', slop[:name]
    assert slop.name?
  end

  test 'parsing options with options as arguments' do
    slop = Slop.new { on :f, :foo, true }
    assert_raises(Slop::MissingArgumentError) { slop.parse %w/-f --bar/ }
  end

  test 'custom IO object' do
    require 'stringio'
    io = StringIO.new
    slop = Slop.new(:help => true, :io => io)
    slop.on :f, :foo, 'something fooey'
    begin
      slop.parse %w/--help/
    rescue SystemExit
    end
    assert io.string.include? 'something fooey'
  end

  test 'exiting when using :help option' do
    require 'stringio'
    io = StringIO.new
    opts = Slop.new(:help => true, :io => io)
    assert_raises(SystemExit) { opts.parse %w/--help/ }

    opts = Slop.new(:help => true, :io => io, :exit_on_help => false)
    assert opts.parse %w/--help/
  end
end
