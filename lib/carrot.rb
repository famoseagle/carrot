class Carrot
  module AMQP
    HEADER        = "AMQP".freeze
    VERSION_MAJOR = 8
    VERSION_MINOR = 0
    PORT          = 5672
  end
end
  
$:.unshift File.expand_path(File.dirname(File.expand_path(__FILE__)))
require 'carrot/amqp/spec'
require 'carrot/amqp/buffer'
require 'carrot/amqp/exchange'
require 'carrot/amqp/frame'
require 'carrot/amqp/header'
require 'carrot/amqp/queue'
require 'carrot/amqp/server'
require 'carrot/amqp/protocol'

class Carrot
  @logging = false
  class << self
    attr_accessor :logging
  end
  def self.logging?
    @logging
  end
  class Error < StandardError; end

  def initialize(opts = {})
    @opts = opts
  end
  
  def queue(name, opts = {})
    queues[name] ||= AMQP::Queue.new(self, name, opts)
  end

  def server
    @server ||= AMQP::Server.new(@opts)
  end

  def stop
    server.close
    @server = nil
  end
  alias :reset :stop

  def queues
    @queues ||= {}
  end

  def direct(name = 'amq.direct', opts = {})
    exchanges[name] ||= AMQP::Exchange.new(self, :direct, name, opts)
  end

  def topic(name = 'amq.topic', opts = {})
    exchanges[name] ||= AMQP::Exchange.new(self, :topic, name, opts)
  end

  def headers(name = 'amq.match', opts = {})
    exchanges[name] ||= AMQP::Exchange.new(self, :headers, name, opts)
  end

  def exchanges
    @exchanges ||= {}
  end

private

  def log(*args)
    return unless Carrot.logging?
    pp args
    puts
  end
end

#-- convenience wrapper (read: HACK) for thread-local Carrot object

class Carrot
  def Carrot.default
    #-- XXX clear this when connection is closed
    Thread.current[:carrot] ||= Carrot.new
  end

  # Allows for calls to all Carrot instance methods. This implicitly calls
  # Carrot.new so that a new channel is allocated for subsequent operations.
  def Carrot.method_missing(meth, *args, &blk)
    Carrot.default.__send__(meth, *args, &blk)
  end

end
