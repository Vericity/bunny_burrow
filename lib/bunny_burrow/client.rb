require_relative 'base'
require 'securerandom'

module BunnyBurrow
  class Client < Base

    attr_accessor :correlation_id, :details, :result

    def initialize()
      super

      subscribe_to_replies
    end

    def subscribe_to_replies
      Timeout.timeout(timeout) do
        reply_to.subscribe do |_, properties, payload|
          if properties[:correlation_id] == self.correlation_id
            details[:response] = payload if log_response?
            log "Receiving #{details}"
            self.result = payload
            lock.synchronize {condition.signal}
          end
        end
      end
    end


    def publish(payload, routing_key)
      self.result = nil
      self.correlation_id = SecureRandom::uuid

      self.details = {
        routing_key: routing_key,
        reply_to: reply_to
      }
      self.details[:request] = payload if log_request?
      log "Publishing #{details}"

      options = {
        routing_key: routing_key,
        reply_to: reply_to.name,
        persistence: false,
        correlation_id: correlation_id
      }

      topic_exchange.publish(payload.to_json, options)

      lock.synchronize { condition.wait(lock, timeout) }

      self.result
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
