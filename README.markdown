# Carrot

A synchronous amqp client. Based on Aman's amqp client:

[http://github.com/tmm1/amqp/tree/master] (http://github.com/tmm1/amqp/tree/master)

## Example
    
    q = Carrot.queue('name', :durable => true, :host => 'q1.rabbitmq.com')
    100.times do
      q.publish('foo')
    end
    
    pp :count, q.message_count
    
    while msg = q.pop(:ack => true)
      puts msg
      q.ack
    end
    Carrot.stop
    
# LICENSE

Copyright (c) 2009 Amos Elliston, Geni.com; Published under The MIT License, see License
