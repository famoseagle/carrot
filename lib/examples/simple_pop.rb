require File.dirname(File.expand_path(__FILE__)) + '/../carrot'

#Carrot.logging = true
q = Carrot.queue('carrot', :durable => true)
100.times do
  q.publish('foo', :persistent => true)
end
puts "count: #{q.message_count}"
while msg = q.pop(:ack => true)
  puts msg
  q.ack
end
Carrot.stop
