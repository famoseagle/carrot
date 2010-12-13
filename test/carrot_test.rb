require 'test_helper'

context 'test queue' do
  TEST_QUEUE = '_carrot_test'
  setup do
    @carrot = Carrot.new
    @q      = @carrot.queue(TEST_QUEUE)
    @q.purge
  end

  test "large messages" do
    msg = 'a' * 1024 * 1024
    @q.publish(msg)
    assert_equal msg, @q.pop
  end

  test "reset" do
    count = @q.message_count
    @q.publish('test')
    @carrot.reset
    assert_equal count + 1, @q.message_count
  end
end
