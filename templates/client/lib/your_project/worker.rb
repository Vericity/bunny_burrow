require 'bunny_burrow'

module YourProject
  class Worker
    attr_reader :config

    ROUTING_KEY = 'some.routing.key'

    def initialize(config)
      @config = config
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
        client.tls_cert = config.rabbitmq_tls_cert
        client.tls_key = config.rabbitmq_tls_key

        tls_ca_certs = (config.rabbitmq_tls_ca_certs || '').split(',')
        client.tls_ca_certs = tls_ca_certs if tls_ca.certs.any?

        client.verify_peer = (config.rabbitmq_verify_peer || 'false') == 'true'

        client.rabbitmq_url = config.rabbitmq_url
        client.rabbitmq_exchange = config.rabbitmq_exchange
        client.log_prefix = config.bunny_burrow_log_prefix || 'CLIENT'
        client.log_request = config.bunny_burrow_log_request || false
        client.log_response = config.bunny_burrow_log_response || false

        STDOUT.sync = true
        client.logger = Logger.new(STDOUT)
      end
    end
  end
end
