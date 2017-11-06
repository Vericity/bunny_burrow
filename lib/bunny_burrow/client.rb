require_relative 'base'
require 'securerandom'

module BunnyBurrow
  class Client < Base

    DIRECT_REPLY_TO = 'amq.rabbitmq.reply-to'


    def publish(payload, routing_key)
      result = nil

      details = {
        routing_key: routing_key,
        reply_to: DIRECT_REPLY_TO
      }

      details[:request] = payload if log_request?
      log "Publishing #{details}"

      options = {
        routing_key: routing_key,
        reply_to: DIRECT_REPLY_TO,
        persistence: false
      }

      consumer = Bunny::Consumer.new(channel, DIRECT_REPLY_TO, SecureRandom.uuid)
      consumer.on_delivery do |_, _, received_payload|
        result = handle_delivery(details, received_payload)
      end


      begin
        channel.basic_consume_with consumer
        topic_exchange.publish(payload.to_json, options)

        Timeout.timeout(timeout) do
          lock.synchronize {condition.wait(lock)}
        end
      ensure
        consumer.cancel
      end
      result
    end

    def handle_delivery(details, payload)
      details[:response] = payload if log_response?
      log "Receiving #{details}"
      result = payload
      lock.synchronize {condition.signal}
      result
    end
  end
end
