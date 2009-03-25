require 'carrot/exchange'
require 'carrot/queue'
require 'carrot/header'

class Carrot
  class << self
    @logging = false
    attr_accessor :logging
  end
  class Error < StandardError; end
end

class Carrot

  def initialize(opts)
    @server = Server.new(opts)
  end
  
  def queue(name, opts = {})
    queues[name] ||= Queue.new(self, name, opts)
  end

  def close
    @server.close
  end

  def queues
    @queues ||= {}
  end

private

  def log *args
    return unless MQ.logging
    pp args
    puts
  end
end
