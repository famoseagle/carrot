require 'test_helper'

class CarrotTest < Test::Unit::TestCase
  TEST_QUEUE = '_carrot_test'

  test "simple server connection" do
    c = Carrot.new
  end

  test "large messages" do
    msg = 'a' * 1024 * 1024
    q = Carrot.queue(TEST_QUEUE)
    q.publish(msg)
    assert_equal msg, q.pop
  end

  test "reset" do
    c = Carrot.new
    q = c.queue(TEST_QUEUE)
    count = q.message_count
    q.publish('test')
    c.reset
    assert_equal count + 1, q.message_count
  end
end
