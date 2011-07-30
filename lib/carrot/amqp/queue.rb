module Carrot::AMQP
  class Queue
    attr_reader   :name, :carrot
    attr_accessor :delivery_tag, :opts

    def initialize(carrot, name, opts = {})
      @opts   = opts
      @name   = name
      @carrot = carrot

      @opts[:queue] = name
      server.send_frame(
        Protocol::Queue::Declare.new(@opts.merge(:nowait => true))
      )
    end

    def pop(opts = {})
      self.delivery_tag = nil
      server.send_frame(
        Protocol::Basic::Get.new({ :queue => name, :consumer_tag => name, :no_ack => !opts.delete(:ack), :nowait => true }.merge(opts))
      )
      method = server.next_method
      return unless method.kind_of?(Protocol::Basic::GetOk)

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
    
    def status
      server.send_frame(
        Protocol::Queue::Declare.new(opts)
      )
      method = server.next_method
      return [nil, nil] if method.kind_of?(Protocol::Connection::Close)

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

    def purge(opts = {})
      server.send_frame(
        Protocol::Queue::Purge.new({ :queue => name, :nowait => true }.merge(opts))
      )
    end

    def server
      carrot.server
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
