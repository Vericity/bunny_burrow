require 'spec_helper'

describe BunnyBurrow::Client do
  let(:channel)   { double 'channel' }
  let(:lock)      { double 'Mutex', synchronize: true, wait: false }
  let(:condition) { double 'condition', signal: true, wait: false }
  let(:response)  { { answer: 'the thing you asked for' } }

  before(:each) do
    allow(subject).to receive(:channel).and_return(channel)
    allow(subject).to receive(:timeout).and_return(1)
    allow(subject).to receive(:lock).and_return(lock)
  end

  subject { described_class.new }

  describe 'instance' do
    it 'should inherit from BunnyBurrow::Base' do
      expect(subject.class.ancestors).to include(BunnyBurrow::Base)
    end


  end # describe 'instance'

  describe '#publish' do
    let(:consumer)       { double Bunny::Consumer, cancel: nil }
    let(:request)        { { question: 'gimme the thing' } }
    let(:routing_key)    { 'routing.key' }
    let(:topic_exchange) { double 'topic exchange' }

    before(:each) do
      allow(Bunny::Consumer).to receive(:new).and_return(consumer)
      allow(consumer).to receive(:on_delivery)
      allow(channel).to receive(:topic).and_return(topic_exchange)
      allow(channel).to receive(:basic_consume_with)
      allow(subject).to receive(:log)
      allow(topic_exchange).to receive(:publish)
    end

    it 'publishes the request on the topic exchange' do
      options = {
        routing_key: routing_key,
        reply_to: BunnyBurrow::Client::DIRECT_REPLY_TO,
        persistence: false
      }
      expect(topic_exchange).to receive(:publish).with(request.to_json, hash_including(options))
      subject.publish request, routing_key
    end

    it 'logs publishing details without the request' do
      allow(subject).to receive(:log_request?).and_return(false)
      expect(subject).to receive(:log).with(/^Publishing(?!.*request).*/)
      subject.publish request, routing_key
    end

    it 'logs publishing details with the request' do
      allow(subject).to receive(:log_request?).and_return(true)
      expect(subject).to receive(:log).with(/^Publishing(?=.*request).*/)
      subject.publish request, routing_key
    end

    it 'does not rescue timeout errors' do
      allow(lock).to receive(:synchronize).and_raise(Timeout::Error.new)
      # expect it to get all the way up
      expect { subject.publish request, routing_key }.to raise_error(Timeout::Error)
    end

    it 'does not rescue unexpected errors' do
      allow(subject).to receive(:log_request?).and_raise(RuntimeError.new)
      # expect it to get all the way up
      expect { subject.publish request, routing_key }.to raise_error(RuntimeError)
    end

    context 'consumer' do
      it 'creates a consumer to consume the reply-to pseudo-queue' do
        expect(Bunny::Consumer).to receive(:new).with(channel, BunnyBurrow::Client::DIRECT_REPLY_TO, an_instance_of(String))
        subject.publish request, routing_key
      end

      it 'consumes the direct reply-to pseudo-queue' do
        expect(channel).to receive(:basic_consume_with).with(consumer)
        subject.publish request, routing_key
      end

      it 'delegates deliveries to #handle_delivery' do
        details = {}
        expect(consumer).to receive(:on_delivery) do |_, _, payload|
          result = subject.handle_delivery(details, payload)
        end
        subject.publish request, routing_key
      end
    end

  end # describe '#publish'

  describe '#handle_delivery' do

    let(:details) { {} }

    it 'logs receiving details without the response' do
      allow(subject).to receive(:log_response?).and_return(false)
      expect(subject).to receive(:log).with(/^Receiving(?!.*response).*/)
      subject.handle_delivery details, response
    end

    it 'logs receiving details with the response' do
      allow(subject).to receive(:log_response?).and_return(true)
      expect(subject).to receive(:log).with(/^Receiving(?=.*response).*/)
      subject.handle_delivery details, response
    end

    it 'returns the response' do
      result = subject.handle_delivery details, response
      expect(result).to eq(response)
    end

    it 'releases the lock' do
      expect(lock).to receive(:synchronize) { condition.signal }
      subject.handle_delivery details, response
    end
  end

  describe '#shutdown' do
    let(:connection) { double 'Bunny' }
    let(:channel)    { double 'channel' }

    before(:each) do
      allow(channel).to receive(:close)
      allow(connection).to receive(:close)
      allow(subject).to receive(:connection).and_return(connection)
      allow(subject).to receive(:channel).and_return(channel)
      allow(subject).to receive(:log)
    end

    it 'shuts down' do
      subject.shutdown
      expect(subject.instance_variable_get('@shutdown')).to be_truthy
    end
  end # describe '#shutdown'
end # describe BunnyBurrow::Client

