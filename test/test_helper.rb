require 'rubygems'
require 'test/unit'
#require 'shoulda'
require 'mocha'
require File.dirname(__FILE__) + '/../lib/carrot'

class << Test::Unit::TestCase
  def test(name, &block)
    test_name = "test_#{name.gsub(/[\s\W]/,'_')}"
    raise ArgumentError, "#{test_name} is already defined" if self.instance_methods.include? test_name
    define_method test_name, &block
  end

  def xtest(name, &block)
    # no-op, an empty test method is defined to prevent "no tests in testcase" errors when all tests are disabled
    define_method(:test_disabled) { assert true }
  end
end
