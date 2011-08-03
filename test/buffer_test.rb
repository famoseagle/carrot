require 'test_helper'
require 'carrot/amqp/buffer'

module Carrot::AMQP
  context 'Buffer' do
    setup do
      @buf = Buffer.new
    end

    test 'have contents' do
      assert_equal '', @buf.contents
    end

    test 'initialize with data' do
      @buf = Buffer.new('abc')
      assert_equal 'abc', @buf.contents
    end

    test 'append raw data' do
      @buf << 'abc'
      @buf << 'def'
      assert_equal 'abcdef', @buf.contents
    end

    test 'append other buffers' do
      @buf << Buffer.new('abc')
      assert_equal 'abc', @buf.contents
    end

    test 'have a position' do
      assert_equal 0, @buf.pos
    end

    test 'have a length' do
      assert_equal 0, @buf.length
      @buf << 'abc'
      assert_equal 3, @buf.length
    end

    test 'know the end' do
      assert_equal true, @buf.empty?
    end

    test 'read and write data' do
      @buf._write('abc')
      @buf.rewind
      assert_equal 'ab', @buf._read(2)
      assert_equal 'c', @buf._read(1)
    end

    test 'raise on overflow' do
      assert_raise(Buffer::Overflow) { @buf._read(1) }
    end

    test 'raise on invalid types' do
      assert_raise(Buffer::InvalidType) { @buf.read(:junk) }
      assert_raise(Buffer::InvalidType) { @buf.write(:junk, 1) }
    end

    { :octet => 0b10101010,
      :short => 100,
      :long => 100_000_000,
      :longlong => 666_555_444_333_222_111,
      :shortstr => 'hello',
      :longstr => 'bye'*500,
      :timestamp => time = Time.at(Time.now.to_i),
      :table => { :this => 'is', :a => 'hash', :with => {:nested => 123, :and => time, :also => 123.456} },
      :bit => true
    }.each do |type, value|

      test "read and write a #{type}" do
        @buf.write(type, value)
        @buf.rewind
        assert_equal value, @buf.read(type)
        assert_equal true, @buf.empty?
      end

    end

    test 'read and write multiple bits' do
      bits = [true, false, false, true, true, false, false, true, true, false]
      @buf.write(:bit, bits)
      @buf.write(:octet, 100)

      @buf.rewind

      assert_equal bits, bits.collect{ @buf.read(:bit) }
      assert_equal 100, @buf.read(:octet)
    end

    test 'read and write properties' do
      properties = ([
                    [:octet, 1],
                    [:shortstr, 'abc'],
                    [:bit, true],
                    [:bit, false],
                    [:shortstr, nil],
                    [:timestamp, nil],
                    [:table, { :a => 'hash' }],
      ]*5).sort_by{rand}

      @buf.write(:properties, properties)
      @buf.rewind
      assert_equal properties.map{|_,value| value }, @buf.read(:properties, *properties.map{|type,_| type })
      assert_equal true, @buf.empty?
    end

    test 'do transactional reads with #extract' do
      @buf.write :octet, 8
      orig = @buf.to_s

      @buf.rewind
      @buf.extract do |b|
        b.read :octet
        b.read :short
      end

      assert_equal 0, @buf.pos
      assert_equal orig, @buf.data
    end
  end
end
