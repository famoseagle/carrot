module Carrot::AMQP
  class Queue
    attr_reader :name, :server, :carrot
    attr_accessor :delivery_tag

    def initialize(carrot, name, opts = {})
      @server = carrot.server
      @opts   = opts
      @name   = name
      @carrot = carrot
      server.send_frame(
        Protocol::Queue::Declare.new({ :queue => name, :nowait => true }.merge(opts))
      )
    end

    def pop(opts = {})
      self.delivery_tag = nil
      server.send_frame(
        Protocol::Basic::Get.new({ :queue => name, :consumer_tag => name, :no_ack => !opts.delete(:ack), :nowait => true }.merge(opts))
      )
      method = server.next_method
      return unless method.is_a?(Protocol::Basic::GetOk)

      self.delivery_tag = method.delivery_tag

      header = server.next_payload

      msg = ''
      while msg.length < header.size
        msg << server.next_payload
      end

      msg
    end

    def ack
      server.send_frame(
        Protocol::Basic::Ack.new(:delivery_tag => delivery_tag)
      )
    end

    def publish(data, opts = {})
      exchange.publish(data, opts)
    end

    def message_count
      status.first
    end

    def consumer_count
      status.last
    end
    
    def status(opts = {}, &blk)
      server.send_frame(
        Protocol::Queue::Declare.new({ :queue => name, :passive => true }.merge(opts))
      )
      method = server.next_method
      [method.message_count, method.consumer_count]
    end

    def bind(exchange, opts = {})
      exchange           = exchange.respond_to?(:name) ? exchange.name : exchange
      bindings[exchange] = opts
      server.send_frame(
        Protocol::Queue::Bind.new({ :queue => name, :exchange => exchange, :routing_key => opts.delete(:key), :nowait => true }.merge(opts))
      )
    end

    def unbind(exchange, opts = {})
      exchange = exchange.respond_to?(:name) ? exchange.name : exchange
      bindings.delete(exchange)

      server.send_frame(
        Protocol::Queue::Unbind.new({
          :queue => name, :exchange => exchange, :routing_key => opts.delete(:key), :nowait => true }.merge(opts)
        )
      )
    end

    def delete(opts = {})
      server.send_frame(
        Protocol::Queue::Delete.new({ :queue => name, :nowait => true }.merge(opts))
      )
      carrot.queues.delete(name)
    end

  private
    def exchange
      @exchange ||= Exchange.new(carrot, :direct, '', :key => name)
    end

    def bindings
      @bindings ||= {}
    end
  end
end
