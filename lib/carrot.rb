class Carrot
  module AMQP
    HEADER        = "AMQP".freeze
    VERSION_MAJOR = 8
    VERSION_MINOR = 0
    PORT          = 5672
  end
end
  
$:.unshift File.expand_path(File.dirname(File.expand_path(__FILE__)))
require 'amqp/spec'
require 'amqp/buffer'
require 'amqp/exchange'
require 'amqp/frame'
require 'amqp/header'
require 'amqp/queue'
require 'amqp/server'
require 'amqp/protocol'

class Carrot
  @logging = false
  class << self
    attr_accessor :logging
  end
  def self.logging?
    @logging
  end
  class Error < StandardError; end

  def self.queue(name, opts = {})
    instance(opts).queue(name, opts)
  end

  def self.stop
    instance.stop
  end

  def self.instance(opts = {})
    @instance ||= new(opts)
  end

  def initialize(opts = {})
    @server = AMQP::Server.new(opts)
  end
  
  def queue(name, opts = {})
    queues[name] ||= AMQP::Queue.new(@server, name, opts)
  end

  def stop
    @server.close
  end

  def queues
    @queues ||= {}
  end

  def send_data(data)
    @server.send_data(data)
  end

  def send_command(cmd)
    @server.send_command(cmd)
  end

private

  def log(*args)
    return unless Carrot.logging?
    pp args
    puts
  end
end
