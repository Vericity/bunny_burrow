require 'spec_helper'

describe BunnyBurrow::Server do
  let(:process_condition) { double 'ConditionVariable' }
  let(:process_lock)      { double 'Mutex' }

  subject { described_class.new }

  describe 'instance' do
    it 'should inherit from BunnyBurrow::Base' do
      expect(subject.class.ancestors).to include(BunnyBurrow::Base)
    end

    it 'creates a process lock when one does not exist' do
      subject.instance_variable_set('@process_lock', nil)
      expect(Mutex).to receive(:new)
      subject.send :process_lock
    end

    it 'uses an existing process lock' do
      subject.instance_variable_set('@process_lock', process_lock)
      expect(Mutex).not_to receive(:new)
      subject.send :process_lock
    end

    it 'creates a process condition when one does not exist' do
      subject.instance_variable_set('@process_condition', nil)
      expect(ConditionVariable).to receive(:new)
      subject.send :process_condition
    end

    it 'uses an existing process condition variable' do
      subject.instance_variable_set('@process_condition', process_condition)
      expect(ConditionVariable).not_to receive(:new)
      subject.send :process_condition
    end
  end # describe 'instance'

  describe '#subscribe' do
    let(:block)            { Proc.new { } }
    let(:channel)          { double 'channel' }
    let(:default_exchange) { double 'default exchange' }
    let(:delivery_info)    { double 'delivery info', delivery_tag: 'some-tag' }
    let(:payload)          { { key: 'value' }.to_json }
    let(:properties)       { double 'properties', reply_to: 'reply.to' }
    let(:queue)            { double 'queue' }
    let(:reply_options)    { { routing_key: properties.reply_to, persistence: false } }
    let(:response)         { { status: BunnyBurrow::STATUS_OK, messages: [], data: { } } }
    let(:routing_key)      { 'routing.key' }
    let(:topic_exchange)   { double 'topic exchange' }

    before(:each) do
      allow(block).to receive(:call).and_return(response)
      allow(default_exchange).to receive(:publish)
      allow(queue).to receive(:name)
      allow(queue).to receive(:bind)
      allow(queue).to receive(:subscribe).and_yield(delivery_info, properties, payload)
      allow(topic_exchange).to receive(:name)
      allow(channel).to receive(:ack)
      allow(channel).to receive(:queue).and_return(queue)
      allow(subject).to receive(:channel).and_return(channel)
      allow(subject).to receive(:default_exchange).and_return(default_exchange)
      allow(subject).to receive(:topic_exchange).and_return(topic_exchange)
      allow(subject).to receive(:log)
    end

    it 'creates a queue on the topic exchange bound to the routing key' do
      options = {
        auto_delete: true,
        exclusive: true
      }
      expect(channel).to receive(:queue).with('', hash_including(options))
      expect(queue).to receive(:bind).with(topic_exchange, hash_including(routing_key: routing_key))
      subject.subscribe routing_key, &block
    end

    it 'logs subscription details' do
      expect(subject).to receive(:log).with(/^Subscribing/)
      subject.subscribe routing_key, &block
    end

    it 'subscribes to the queue' do
      expect(queue).to receive(:subscribe).with(hash_including(manual_ack: true))
      subject.subscribe routing_key, &block
    end

    it 'logs receiving details without the request' do
      allow(subject).to receive(:log_request?).and_return(false)
      expect(subject).to receive(:log).with(/^Receiving(?!.*request).*/)
      subject.subscribe routing_key, &block
    end

    it 'logs receiving details with the request' do
      allow(subject).to receive(:log_request?).and_return(true)
      expect(subject).to receive(:log).with(/^Receiving(?=.*request).*/)
      subject.subscribe routing_key, &block
    end

    it 'yields to the block' do
      expect(block).to receive(:call).with(payload, response)
      subject.subscribe routing_key, &block
    end

    it 'replies on the reply-to queue' do
      expect(default_exchange).to receive(:publish).with(anything, hash_including(reply_options))
      subject.subscribe routing_key, &block
    end

    it 'logs replying details without the response' do
      allow(subject).to receive(:log_response?).and_return(false)
      expect(subject).to receive(:log).with(/^Replying(?!.*response).*/)
      subject.subscribe routing_key, &block
    end

    it 'logs replying details with the response' do
      allow(subject).to receive(:log_response?).and_return(true)
      expect(subject).to receive(:log).with(/^Replying(?=.*response).*/)
      subject.subscribe routing_key, &block
    end

    it 'acks the message' do
      expect(channel).to receive(:ack).with(delivery_info.delivery_tag)
      subject.subscribe routing_key, &block
    end

    it 'logs acknowledging details' do
      expect(subject).to receive(:log).with(/^Acknowledging/)
      subject.subscribe routing_key, &block
    end

    it 'rescues, logs, and replies with server side errors' do
      error_message = 'Kaboom'
      error_regex = /(?=.*#{BunnyBurrow::STATUS_SERVER_ERROR})(?=.*#{error_message}).*/
      allow(block).to receive(:call).and_raise RuntimeError.new(error_message)
      expect(subject).to receive(:log).with(error_message, level: :error)
      expect(default_exchange).to receive(:publish).with(error_regex, hash_including(reply_options))
      subject.subscribe routing_key, &block
    end

    it 'rescues and logs unexpected errors' do
      error_message = 'Kaboom'
      allow(channel).to receive(:queue).and_raise(RuntimeError.new(error_message))
      expect(subject).to receive(:log).with(error_message, level: :error)
      expect(default_exchange).not_to receive(:publish)
      subject.subscribe routing_key, &block
    end
  end # describe '#subscribe'

  describe '#wait' do
    before(:each) do
      allow(process_condition).to receive(:wait)
      allow(process_lock).to receive(:synchronize).and_yield
      allow(subject).to receive(:process_condition).and_return(process_condition)
      allow(subject).to receive(:process_lock).and_return(process_lock)
    end

    it 'keeps the process alive' do
      expect(process_lock).to receive(:synchronize)
      expect(process_condition).to receive(:wait).with(process_lock)
      subject.wait
    end
  end # describe '#wait'

  describe '#stop_waiting' do
    before(:each) do
      allow(process_condition).to receive(:signal)
      allow(process_lock).to receive(:synchronize).and_yield
      allow(subject).to receive(:process_condition).and_return(process_condition)
      allow(subject).to receive(:process_lock).and_return(process_lock)
    end

    it 'lets the process stop' do
      expect(process_lock).to receive(:synchronize)
      expect(process_condition).to receive(:signal)
      subject.stop_waiting
    end
  end # describe '#stop_waiting'

  describe '#shutdown' do
    let(:connection) { double 'Bunny' }
    let(:channel)    { double 'channel' }

    before(:each) do
      allow(channel).to receive(:close)
      allow(connection).to receive(:close)
      allow(subject).to receive(:connection).and_return(connection)
      allow(subject).to receive(:channel).and_return(channel)
      allow(subject).to receive(:log)
      allow(subject).to receive(:stop_waiting)
    end

    it 'logs shutting down' do
      expect(subject).to receive(:log).with('Shutting down')
      subject.shutdown
    end

    it 'stops waiting' do
      expect(subject).to receive(:stop_waiting)
      subject.shutdown
    end

    it 'closes the channel' do
      expect(channel).to receive(:close)
      subject.shutdown
    end

    it 'closes the connection' do
      expect(connection).to receive(:close)
      subject.shutdown
    end
  end # describe '#shutdown'
end # describe Server