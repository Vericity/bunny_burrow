require 'bunny_burrow'

module YourProject
  class Worker
    ROUTING_KEY_ONE = 'some.routing.key.one'
    ROUTING_KEY_TWO = 'some.routing.key.two'

    attr_reader :context

    def initialize(context)
      @context = context
    end

    def run
      rpc_server.subscribe(ROUTING_KEY_ONE) do |payload, response|
        begin
          response[:data] = method_one(payload)
        rescue => exception
          handle_exception exception, response
        end

        response
      end

      rpc_server.subscribe(ROUTING_KEY_TWO) do |payload, response|
        begin
          response[:data] = method_two(payload)
        rescue => exception
          handle_exception exception, response
        end

        response
      end

      rpc_server.wait
    end

    def method_one(payload)
      payload = JSON.parse(payload)
      { message: "method_one executed" }
    end

    def method_two(payload)
      payload = JSON.parse(payload)
      { message: "method_two executed" }
    end

    def shutdown
      rpc_server.shutdown
    end

    private

    def rpc_server
      @rpc_server ||= BunnyBurrow::Server.new do |server|
        server.rabbitmq_url = context.rabbitmq_url
        server.rabbitmq_exchange = context.rabbitmq_exchange
        server.logger = Logger.new(STDOUT)
      end
    end

    def handle_exception(exception, response)
      response[:messages] << exception.message
      response[:status] =
        case exception.class
          when YourClientError
            BunnyBurrow::STATUS_CLIENT_ERROR
          else
            BunnyBurrow::STATUS_SERVER_ERROR
        end
    end
  end
end
