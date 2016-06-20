require 'bunny_burrow'

module YourProject
  class Worker
    attr_reader :context

    ROUTING_KEY = 'some.routing.key'

    def initialize(context)
      @context = context
    end

    def run
      payload = { question: 'the thing you want' }
      result = rpc_client.publish(payload, ROUTING_KEY)
      puts result
    end

    def shutdown
      rpc_client.shutdown
    end

    private

    def rpc_client
      @rpc_client ||= BunnyBurrow::Client.new do |client|
        client.rabbitmq_url = context.rabbitmq_url
        client.rabbitmq_exchange = context.rabbitmq_exchange
        client.logger = Logger.new(STDOUT)
      end
    end
  end
end
