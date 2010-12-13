require 'test_helper'

module Carrot::AMQP 
  context 'Protocol' do
    test 'instantiate methods with arguments' do
      meth = Protocol::Connection::StartOk.new(nil, 'PLAIN', nil, 'en_US')
      assert_equal 'en_US', meth.locale
    end

    test 'instantiate methods with named parameters' do
      meth = Protocol::Connection::StartOk.new(:locale => 'en_US', :mechanism => 'PLAIN')
      assert_equal 'en_US', meth.locale
    end

    test 'convert methods to binary' do
      meth = Protocol::Connection::Secure.new(:challenge => 'secret')
      assert meth.to_binary.kind_of?(Buffer)

      assert_equal  [ 10, 20, 6, 'secret' ].pack('nnNa*'), meth.to_s
    end

    test 'convert binary to method' do
      orig = Protocol::Connection::Secure.new(:challenge => 'secret')
      copy = Protocol.parse orig.to_binary
      assert_equal copy, orig
    end

    test 'convert headers to binary' do
      head = Protocol::Header.new(
        Protocol::Basic,
        size = 5,
        weight = 0,
        :content_type  => 'text/json',
        :delivery_mode => 1,
        :priority      => 1
      )
      assert_equal [ 60, weight, 0, size, 0b1001_1000_0000_0000, 9, 'text/json', 1, 1 ].pack('nnNNnCa*CC'), head.to_s
    end

    test 'convert binary to header' do
      orig = Protocol::Header.new(
        Protocol::Basic,
        size = 5,
        weight = 0,
        :content_type  => 'text/json',
        :delivery_mode => 1,
        :priority      => 1
      )
      assert_equal orig, Protocol::Header.new(orig.to_binary)
    end
  end
end
