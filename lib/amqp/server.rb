require 'socket'
require 'thread'
require 'timeout'

begin
  require 'openssl'
rescue LoadError
  warn "Unable to load SSL extension - you will be unable to make ssl connections."
end

module Carrot::AMQP
  class Server
    CONNECT_TIMEOUT = 1.0
    RETRY_DELAY     = 10.0
    DEFAULT_PORT    = 5672

    attr_reader   :host, :port, :status
    attr_accessor :channel, :ticket

    class ServerDown      < StandardError; end
    class ProtocolError   < StandardError; end

    def initialize(opts = {})
      @host   = opts[:host]  || 'localhost'
      @port   = opts[:port]  || DEFAULT_PORT
      @user   = opts[:user]  || 'guest'
      @pass   = opts[:pass]  || 'guest'
      @vhost  = opts[:vhost] || '/'
      @insist = opts[:insist]
      @status = 'NOT CONNECTED'

      @use_ssl    = !!opts[:ssl]
      @ssl_verify = opts[:ssl_verify] || OpenSSL::SSL::VERIFY_PEER

      @multithread = opts[:multithread]      
      start_session
    end

    def send_frame(*args)
      args.each do |data|
        data.ticket  = ticket if ticket and data.respond_to?(:ticket=)
        data         = data.to_frame(channel) unless data.is_a?(Frame)
        data.channel = channel

        log :send, data
        write(data.to_s)
      end
      nil
    end

    def next_frame
      frame = Frame.parse(buffer)
      log :received, frame
      frame
    end

    def next_method
      next_payload
    end

    def next_payload
      frame = next_frame
      frame and frame.payload
    end

    def close
      send_frame(
        Protocol::Channel::Close.new(:reply_code => 200, :reply_text => 'bye', :method_id => 0, :class_id => 0)
      )
      puts "Error closing channel #{channel}" unless next_method.is_a?(Protocol::Channel::CloseOk)

      self.channel = 0
      send_frame(
        Protocol::Connection::Close.new(:reply_code => 200, :reply_text => 'Goodbye', :class_id => 0, :method_id => 0)
      )
      puts "Error closing connection" unless next_method.is_a?(Protocol::Connection::CloseOk)

    rescue ServerDown => e
    ensure
      close_socket
    end

    def read(*args)
      send_command(:read, *args)
    end

    def write(*args)
      send_command(:write, *args)
    end

  private

    def buffer
      @buffer ||= Buffer.new(self)
    end

    def send_command(cmd, *args)
      begin
        socket.__send__(cmd, *args)
      rescue Errno::EPIPE, IOError, Errno::ECONNRESET, Errno::EINVAL => e
        raise ServerDown, e.message
      end
    end

    def start_ssl
      unless defined?(OpenSSL)
        raise "SSL Extension not installed"
      end

      ctx = OpenSSL::SSL::SSLContext.new
      ctx.verify_mode = @ssl_verify

      @socket = OpenSSL::SSL::SSLSocket.new(@socket, ctx)
      @socket.sync_close = true
      @socket.connect

      if ctx.verify_mode != OpenSSL::SSL::VERIFY_NONE
        @socket.post_connection_check(@host)
      end
    end

    def socket
      return @socket if @socket and not @socket.closed?

      begin
        # Attempt to connect.
        mutex.lock if multithread?
        @socket = timeout(CONNECT_TIMEOUT) do
          TCPSocket.new(host, port)
        end

        if Socket.constants.include? 'TCP_NODELAY'
          @socket.setsockopt Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1
        end

        start_ssl if @use_ssl

        @status   = 'CONNECTED'
      rescue SocketError, SystemCallError, IOError, Timeout::Error => e
        msg = e.message << " - #{@host}:#{@port}"
        raise ServerDown, e.message
      ensure
        mutex.unlock if multithread?
      end

      @socket
    end

    def start_session
      @channel = 0
      write(HEADER)
      write([1, 1, VERSION_MAJOR, VERSION_MINOR].pack('C4'))
      raise ProtocolError, 'bad start connection' unless next_method.is_a?(Protocol::Connection::Start)

      send_frame(
        Protocol::Connection::StartOk.new(
          {:platform => 'Ruby', :product => 'Carrot', :information => 'http://github.com/famosagle/carrot', :version => RUBY_VERSION},
          'AMQPLAIN',
          {:LOGIN => @user, :PASSWORD => @pass},
          'en_US'
        )
      )

      method = next_method
      raise ProtocolError, "Bad AMQP Credentials. user: #{@user}, pass: #{@pass}" if method.nil?

      if method.is_a?(Protocol::Connection::Tune)
        send_frame(
          Protocol::Connection::TuneOk.new( :channel_max => 0, :frame_max => 131072, :heartbeat => 0)
        )
      end

      send_frame(
        Protocol::Connection::Open.new(:virtual_host => @vhost, :capabilities => '', :insist => @insist)
      )
      raise ProtocolError, 'bad open connection' unless next_method.is_a?(Protocol::Connection::OpenOk)

      @channel = 1
      send_frame(Protocol::Channel::Open.new)
      raise ProtocolError, "cannot open channel #{channel}" unless next_method.is_a?(Protocol::Channel::OpenOk)

      send_frame(
        Protocol::Access::Request.new(:realm => '/data', :read => true, :write => true, :active => true, :passive => true)
      )
      method = next_method
      raise ProtocolError, 'access denied' unless method.is_a?(Protocol::Access::RequestOk)
      self.ticket = method.ticket
    end

    def multithread?
      @multithread
    end

    def close_socket(reason=nil)
      # Close the socket. The server is not considered dead.
      mutex.lock if multithread?
      @socket.close if @socket and not @socket.closed?
      @socket   = nil
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
