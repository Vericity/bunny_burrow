require_relative 'base'

module BunnyBurrow
  class Server < Base
    def self.create_response
      {
        status: STATUS_OK,
        error_message: nil,
        data: {}
      }
    end

    def subscribe(routing_key, &block)
      queue = channel.queue('', exclusive: true, auto_delete: true)
      queue.bind(topic_exchange, routing_key: routing_key)

      details = {
        routing_key: routing_key,
        queue: queue.name,
        exchange: topic_exchange.name
      }

      log "Subscribing #{details}"
      queue.subscribe(manual_ack: true) do |delivery_info, properties, payload|
        begin
          details = {
            delivery_info: delivery_info,
            properties: properties
          }

          details[:request] = payload if log_request?
          log "Receiving #{details}"

          response = block.call(payload)

          details[:response] = response if log_response?

          log "Replying #{details}"
          default_exchange.publish(response.to_json, :routing_key => properties.reply_to, persistence: false)

          log "Acknowledging #{details}"
          channel.ack delivery_info.delivery_tag
        rescue => e
          log e.message, level: :error
          response = {
            status: STATUS_SERVER_ERROR,
            error_message: e.message
          }
          default_exchange.publish(response.to_json, :routing_key => properties.reply_to, persistence: false)
        end
      end
    rescue => e
      log e.message, level: :error
    end

    def wait
      @waiting = true
      process_lock.synchronize { process_condition.wait(process_lock) }
    end

    def stop_waiting
      return unless @waiting
      process_lock.synchronize { process_condition.signal }
      @waiting = false
    end

    def shutdown
      stop_waiting
      super
    end

    private

    def process_lock
      @process_lock ||= Mutex.new
    end

    def process_condition
      @process_condition ||= ConditionVariable.new
    end
  end
end
