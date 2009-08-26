require File.dirname(__FILE__) + '/test_helper'

class CarrotTest < Test::Unit::TestCase

  test "simple server connection" do
    c = Carrot.new
  end

  test "large messages" do
    msg = 'a' * 1024 * 1024
    q = Carrot.queue('_carrot_test')
    q.publish(msg)
    assert_equal msg, q.pop
  end
end
