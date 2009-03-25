require 'amqp/frame'

class Carrot
  class Error < StandardError; end
  class Server
    CONNECT_TIMEOUT = 1.0
    RETRY_DELAY     = 10.0
    DEFAULT_PORT    = 56

    attr_reader :host, :port, :status
    attr_accessor :retry_at

    def initialize(opts = {})
      @host   = opts[:host]
      @port   = opts[:port]   || DEFAULT_PORT
      @status = 'NOT CONNECTED'
      @readonly    = opts[:readonly]
      @multithread = opts[:multithread]      
      send(Protocol::Channel::Open.new)
    end

    def send(data, opts = {}, &block)
      channel = opts[:channel] ||= 0
      data = data.to_frame(channel) unless data.is_a? Frame
      data.channel = channel

      log 'send', data
      send_command(data.to_s, &block)
    end

  private
    def receive_data(data, &block)
      @buf << data

      while frame = Frame.parse(@buf)
        log 'receive', frame
        process_frame(frame)
      end
    end

    def process_frame(frame, &block)
      log :received, frame

      case frame
      when Frame::Header
        @header = frame.payload
        @body = ''

      when Frame::Body
        @body << frame.payload
        if @body.length >= @header.size
          @header.properties.update(@method.arguments)
          block.call(@header, @body) if block
          @body = @header = @consumer = @method = nil
        end

      when Frame::Method
        case method = frame.payload
        when Protocol::Channel::OpenOk
          send(
            Protocol::Access::Request.new(:realm => '/data', :read => true, :write => true, :active => true, :passive => true)
          )

        when Protocol::Access::RequestOk
          block.call(method) if block

        when Protocol::Basic::CancelOk
          block.call if block

        when Protocol::Queue::DeclareOk
          block.call(method) if block

        when Protocol::Basic::Deliver, Protocol::Basic::GetOk
          @method = method
          @header = nil
          @body   = ''

        when Protocol::Basic::GetEmpty
          block.call(nil) if block

        when Protocol::Channel::Close
          raise Error, "#{method.reply_text} in #{Protocol.classes[method.class_id].methods[method.method_id]} on #{@channel}"

        when Protocol::Channel::CloseOk
          kill
        end
      end
    end
  
    def log(*args)
      return unless Carrot.log?
      require 'pp'
      pp args
      puts
    end

    def send_command(data, &block)
      retried = false
      begin
        mutex.lock if multithread?
        command = command.join("\r\n") if command.kind_of?(Array)
        socket.write("#{command}")
        response = socket.gets
        
        unexpected_eof! if response.nil?
        if response =~ /^(ERROR|CLIENT_ERROR|SERVER_ERROR) (.*)\r\n/
          raise ($1 == 'SERVER_ERROR' ? ServerError : ClientError), $2
        end

        process_frame(&block)

      rescue ClientError, ServerError, SocketError, SystemCallError, IOError => error
        if not retried
          # Close the socket and retry once.
          close
          retried = true
          retry
        else
          # Mark the server dead and raise an error.
          kill(error.message)

          # Reraise as a ConnectionError
          new_error = ConnectionError.new("#{error.class}: #{error.message}")
          new_error.set_backtrace(error.backtrace)
          raise new_error
        end
      ensure
        mutex.unlock if multithread?
      end
    end

    def socket
      return @socket if @socket and not @socket.closed?
      raise ServerDown, "will retry at #{retry_at}" unless retry?

      begin
        # Attempt to connect.
        mutex.lock if multithread?
        @socket = timeout(CONNECT_TIMEOUT) do
          TCPSocket.new(host, port)
        end

        if Socket.constants.include? 'TCP_NODELAY'
          @socket.setsockopt Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1
        end
        @retry_at = nil
        @status   = 'CONNECTED'
      rescue SocketError, SystemCallError, IOError, Timeout::Error => e
        # Connection failed.
        kill(e.message)
        raise ServerDown, e.message
      ensure
        mutex.unlock if multithread?
      end

      @socket
    end

    def unexpected_eof!
      raise ConnectionError, 'unexpected end of file' 
    end

    def kill(reason = 'Unknown error')
      send(
        Protocol::Connection::Close.new(:reply_code => 200, :reply_text => 'Goodbye', :class_id => 0, :method_id => 0),
        Proc.new{
          send(
            Protocol::Channel::Close.new(:reply_code => 200, :reply_text => 'bye', :method_id => 0, :class_id => 0)
          )
        }
      )

      # Mark the server as dead and close its socket.
      @socket.close if @socket and not @socket.closed?
      @socket   = nil
      @retry_at = Time.now + RETRY_DELAY  
      @status   = "DEAD: %s, will retry at %s" % [reason, @retry_at]
    end

    def mutex
      @mutex ||= Mutex.new
    end
  end
end
