require 'socket'
require 'thread'
require 'timeout'

module AMQP
  class Server
    CONNECT_TIMEOUT = 1.0
    RETRY_DELAY     = 10.0
    DEFAULT_PORT    = 5672

    attr_reader   :host, :port, :status
    attr_accessor :retry_at, :channel, :ticket

    class Error           < StandardError; end
    class ConnectionError < Error; end
    class ServerError     < Error; end
    class ClientError     < Error; end
    class ServerDown      < Error; end

    def initialize(opts = {})
      @host   = opts[:host]  || 'localhost'
      @port   = opts[:port]  || DEFAULT_PORT
      @user   = opts[:user]  || 'guest'
      @pass   = opts[:pass]  || 'guest'
      @vhost  = opts[:vhost] || '/'
      @insist = opts[:insist]
      @channel= 0
      @status = 'NOT CONNECTED'

      @multithread = opts[:multithread]      

      write(HEADER)
      write([1, 1, VERSION_MAJOR, VERSION_MINOR].pack('C4'))
      receive_frame
    end

    def multithread?
      @multithread
    end

    def retry?
      @retry_at.nil? or @retry_at < Time.now
    end

    def send_command(*args)
      args.each do |data|
        data.ticket  = ticket if ticket and data.respond_to?(:ticket=)
        data         = data.to_frame(channel) unless data.is_a?(Frame)
        data.channel = channel

        log :send, data
        write(data.to_s)
      end
    end

    def read(*args)
      with_socket do |socket|
        socket.read(*args)
      end
    end

    def write(*args)
      with_socket do |socket|
        socket.write(*args)
      end
    end

    def with_socket(&block)
      retried = false
      begin
        mutex.lock if multithread?
        yield socket

      rescue ClientError, ServerError, SocketError, SystemCallError, IOError => error
        if not retried
          # Close the socket and retry once.
          close_socket
          retried = true
          retry
        else
          # Mark the server dead and raise an error.
          close(error.message)

          # Reraise as a ConnectionError
          new_error = ConnectionError.new("#{error.class}: #{error.message}")
          new_error.set_backtrace(error.backtrace)
          raise new_error
        end
      ensure
        mutex.unlock if multithread?
      end
    end

    def receive_frame(&block)
      frame = Frame.get(self)
      return unless frame

      log :received, frame

      case frame
      when Frame::Header
        @header = frame.payload
        @body = ''
        receive_frame(&block)

      when Frame::Body
        @body << frame.payload
        if @body.length >= @header.size
          @header.properties.update(@method.arguments)
          block.call(@header, @body) if block
          @body = @header = @consumer = @method = nil
        end

      when Frame::Method
        case method = frame.payload
        when Protocol::Connection::Start
          send_command(
            Protocol::Connection::StartOk.new(
              {:platform => 'Ruby', :product => 'Carrot', :information => 'http://github.com/famosagle/carrot', :version => VERSION},
              'AMQPLAIN',
              {:LOGIN => @user, :PASSWORD => @pass},
              'en_US'
            )
          )
          receive_frame

        when Protocol::Connection::Tune
          send_command(
            Protocol::Connection::TuneOk.new( :channel_max => 0, :frame_max => 131072, :heartbeat => 0)
          )
          send_command(
            Protocol::Connection::Open.new(:virtual_host => @vhost, :capabilities => '', :insist => @insist)
          )
          receive_frame

        when Protocol::Connection::Close
          STDERR.puts "#{method.reply_text} in #{Protocol.classes[method.class_id].methods[method.method_id]}"

        when Protocol::Connection::OpenOk
          self.channel = 1
          send_command(Protocol::Channel::Open.new)
          receive_frame

        when Protocol::Channel::OpenOk
          send_command(
            Protocol::Access::Request.new(:realm => '/data', :read => true, :write => true, :active => true, :passive => true)
          )
          receive_frame

        when Protocol::Access::RequestOk
          self.ticket = method.ticket
          block.call(method) if block

        when Protocol::Queue::DeclareOk
          block.call(method) if block

        when Protocol::Basic::CancelOk, Protocol::Connection::CloseOk, Protocol::Channel::CloseOk

        when Protocol::Basic::Deliver, Protocol::Basic::GetOk
          @method = method
          @header = nil
          @body   = ''
          receive_frame(&block)

        when Protocol::Basic::GetEmpty
          block.call(nil) if block

        when Protocol::Channel::Close
          raise Error, "#{method.reply_text} in #{Protocol.classes[method.class_id].methods[method.method_id]} on #{@channel}"

        end
      end
    end

    def close
      send_command(
        Protocol::Channel::Close.new(:reply_code => 200, :reply_text => 'bye', :method_id => 0, :class_id => 0)
      )
      receive_frame
      self.channel = 0
      send_command(
        Protocol::Connection::Close.new(:reply_code => 200, :reply_text => 'Goodbye', :class_id => 0, :method_id => 0)
      )
      receive_frame
      close_socket
    end

  private

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
        close_socket
        raise ServerDown, e.message
      ensure
        mutex.unlock if multithread?
      end

      @socket
    end

    def unexpected_eof!
      raise ConnectionError, 'unexpected end of file' 
    end

    def close_socket(reason=nil)
      # Close the socket. The server is not considered dead.
      mutex.lock if multithread?
      @socket.close if @socket and not @socket.closed?
      @socket   = nil
      @retry_at = nil
      @status   = "NOT CONNECTED"
    ensure
      mutex.unlock if multithread?
    end

    def mutex
      @mutex ||= Mutex.new
    end

    def log(*args)
      return unless Carrot.logging?
      require 'pp'
      pp args
      puts
    end

  end
end
