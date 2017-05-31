require_relative 'base'
require 'securerandom'

module BunnyBurrow
  class Client < Base
    def publish(payload, routing_key)
      result = nil
      correlation_id = SecureRandom::uuid

      details = {
        routing_key: routing_key,
        reply_to: reply_to
      }
      details[:request] = payload if log_request?
      log "Publishing #{details}"

      options = {
        routing_key: routing_key,
        reply_to: reply_to.name,
        persistence: false,
        correlation_id: correlation_id
      }

      topic_exchange.publish(payload.to_json, options)

      Timeout.timeout(timeout) do
        reply_to.subscribe do |_, properties, payload|
          if properties[:correlation_id] == correlation_id
            details[:response] = payload if log_response?
            log "Receiving #{details}"
            result = payload
            lock.synchronize { condition.signal }
          end
        end

        lock.synchronize { condition.wait(lock) }
      end

       result
    end

    private

    def reply_to
      # when creating a queue, a blank name indicates we want the AMPQ broker
      # to generate a unique name for us. Also note that this queue will be on
      # the default exchange
      @reply_to ||= channel.queue('', exclusive: true, auto_delete: true)
    end
  end
end
