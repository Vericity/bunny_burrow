require 'bunny_burrow'

module YourProject
  class Worker
    ROUTING_KEY_ONE = 'some.routing.key.one'
    ROUTING_KEY_TWO = 'some.routing.key.two'

    attr_reader :config

    def initialize(config)
      @config = config
    end

    def run
      rpc_server.subscribe(ROUTING_KEY_ONE) do |request|
        begin
          request = JSON.parse(request)
          response = BunnyBurrow::Server.create_response
          response[:data] = method_one(request)
        rescue => exception
          handle_exception exception, request, response
        end

        response
      end

      rpc_server.subscribe(ROUTING_KEY_TWO) do |request|
        begin
          request = JSON.parse(request)
          response = BunnyBurrow::Server.create_response
          response[:data] = method_two(request)
        rescue => exception
          handle_exception exception, request, response
        end

        response
      end

      rpc_server.wait
    end

    def method_one(request)
      { message: "method_one executed" }
    end

    def method_two(request)
      { message: "method_two executed" }
    end

    def shutdown
      rpc_server.shutdown
    end

    private

    def rpc_server
      @rpc_server ||= BunnyBurrow::Server.new do |server|
        server.tls_cert = config.rabbitmq_tls_cert
        server.tls_key = config.rabbitmq_tls_key

        tls_ca_certs = (config.rabbitmq_tls_ca_certs || '').split(',')
        server.tls_ca_certs = tls_ca_certs if tls_ca.certs.any?

        server.verify_peer = (config.rabbitmq_verify_peer || 'false') == 'true'

        server.rabbitmq_url = config.rabbitmq_url
        server.rabbitmq_exchange = config.rabbitmq_exchange
        server.log_prefix = config.bunny_burrow_log_prefix || 'SERVER'
        server.log_request = config.bunny_burrow_log_request || false
        server.log_response = config.bunny_burrow_log_response || false
        server.timeout = config.bunny_burrow_timeout || 60

        STDOUT.sync = true
        server.logger = Logger.new(STDOUT)
      end
    end

    def handle_exception(exception, request, response)
      if exception.class == YourClientError
        response[:status] = BunnyBurrow::STATUS_CLIENT_ERROR
        response[:data][:status] = exception.message.downcase.gsub(' ', '_')
        message = 'create-appropriate-message-here'
        Raven.capture_message message, tags: request
      else
        response[:status] = BunnyBurrow::STATUS_SERVER_ERROR
        response[:error_message] = exception.message
        Raven.capture_exception exception, tags: request
      end
    end
  end
end
