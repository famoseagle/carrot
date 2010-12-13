require 'test_helper'

module Carrot::AMQP 
  context 'Frame' do
    test 'handle basic frame types' do
      assert_equal 1, Frame::Method.new.id
      assert_equal 2, Frame::Header.new.id
      assert_equal 3, Frame::Body.new.id
    end

    test 'convert method frames to binary' do
      meth = Protocol::Connection::Secure.new :challenge => 'secret'

      frame = Frame::Method.new(meth)
      assert frame.to_binary.kind_of?(Buffer)
      assert_equal [ 1, 0, meth.to_s.length, meth.to_s, 206 ].pack('CnNa*C'), frame.to_s
    end

    test 'convert binary to method frames' do
      orig = Frame::Method.new Protocol::Connection::Secure.new(:challenge => 'secret')

      copy = Frame.parse(orig.to_binary)
      assert_equal orig, copy
    end

    test 'ignore partial frames until ready' do
      frame = Frame::Method.new Protocol::Connection::Secure.new(:challenge => 'secret')
      data = frame.to_s

      buf = Buffer.new
      assert_equal nil, Frame.parse(buf)
      
      buf << data[0..5]
      assert_equal nil, Frame.parse(buf)
      
      buf << data[6..-1]
      assert_equal frame, Frame.parse(buf)
      
      assert_equal nil, Frame.parse(buf)
    end

    test 'convert header frames to binary' do
      head = Protocol::Header.new(Protocol::Basic, :priority => 1)
      
      frame = Frame::Header.new(head)
      assert_equal [ 2, 0, head.to_s.length, head.to_s, 206 ].pack('CnNa*C'), frame.to_s
    end

    test 'convert binary to header frame' do
      orig = Frame::Header.new Protocol::Header.new(Protocol::Basic, :priority => 1)
      
      copy = Frame.parse(orig.to_binary)
      assert_equal orig, copy
    end
  end
end
