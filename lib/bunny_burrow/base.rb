require 'bunny'
require 'json'
require 'thread'

module BunnyBurrow
  STATUS_OK = 'ok'
  STATUS_CLIENT_ERROR = 'client_error'
  STATUS_SERVER_ERROR = 'server_error'

  class Base
    attr_accessor :rabbitmq_url, :rabbitmq_exchange, :logger, :log_prefix
    attr_writer :timeout, :log_request, :log_response

    def initialize
      yield self if block_given?
    end

    def timeout
      @timeout ||= 60
    end

    def log_request?
      @log_request ||= false
    end

    def log_response?
      @log_response ||= false
    end

    def shutdown
      log 'Shutting down'
      channel.close
      connection.close
    end

    private

    def connection
      unless @connection
        @connection = Bunny.new(rabbitmq_url)
        @connection.start
      end

      @connection
    end

    def channel
      @channel ||= connection.create_channel
    end

    def default_exchange
      @default_exchange ||= channel.default_exchange
    end

    def topic_exchange
      @topic_exchange ||= channel.topic(rabbitmq_exchange, durable: true)
    end

    def lock
      @lock ||= Mutex.new
    end

    def condition
      @condition ||= ConditionVariable.new
    end

    def log(message, level: :info)
      return unless logger
      prefix = log_prefix || 'BunnyBurrow'
      message = "#{prefix}: #{message}"
      logger.send(level, message)
    end
  end
end

