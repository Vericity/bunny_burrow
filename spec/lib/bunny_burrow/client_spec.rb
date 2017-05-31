require 'spec_helper'

describe BunnyBurrow::Client do
  let(:channel)  { double 'channel' }
  let(:reply_to) { double 'reply to', name: 'reply.to' }

  before(:each) do
    allow(subject).to receive(:channel).and_return(channel)
    allow(subject).to receive(:timeout).and_return(1)
  end

  subject { described_class.new }

  describe 'instance' do
    it 'should inherit from BunnyBurrow::Base' do
      expect(subject.class.ancestors).to include(BunnyBurrow::Base)
    end

    it 'creates a reply-to queue if one does not exist' do
      subject.instance_variable_set('@reply_to', nil)
      options = {
        exclusive: true,
        auto_delete: true
      }
      expect(channel).to receive(:queue).with('', hash_including(options))
      subject.send :reply_to
    end

    it 'uses existing reply-to queue' do
      subject.instance_variable_set('@reply_to', reply_to)
      expect(channel).not_to receive(:queue)
      subject.send :reply_to
    end
  end # describe 'instance'

  describe '#subscribe_to_replies' do
    let(:condition)      { double 'condition', signal: true, wait: false }
    let(:correlation_id) { 'test-correlation-id' }
    let(:properties)     { { correlation_id: correlation_id } }
    let(:request)        { { question: 'gimme the thing' } }
    let(:response)       { { answer: 'the thing you asked for' } }
    let(:routing_key)    { 'routing.key' }
    let(:topic_exchange) { double 'topic exchange' }

    before(:each) do
      subject.correlation_id = correlation_id
      allow(reply_to).to receive(:subscribe).and_yield({}, properties, response)
      allow(channel).to receive(:topic)
      allow(subject).to receive(:reply_to).and_return(reply_to)
    end

    it 'subscribes to the reply-to queue' do
      expect(reply_to).to receive(:subscribe)
      subject.subscribe_to_replies
    end

    it 'logs receiving details without the response' do
      allow(subject).to receive(:log_response?).and_return(false)
      expect(subject).to receive(:log).with(/^Receiving(?!.*response).*/)
      subject.subscribe_to_replies
    end

    it 'logs receiving details with the response' do
      subject.details = {}
      allow(subject).to receive(:log_response?).and_return(true)
      expect(subject).to receive(:log).with(/^Receiving(?=.*response).*/)
      subject.subscribe_to_replies
    end

    it 'sets the response' do
      subject.subscribe_to_replies
      expect(subject.result).to eq(response)
    end

    context 'when the correlation ID is wrong' do
      let(:properties) { { correlation_id: 'wrong-id-bucko' } }

      it 'ignores the message' do
        expect(subject.subscribe_to_replies).to be_nil
      end
    end

    it 'does not rescue timeout errors' do
      allow(reply_to).to receive(:subscribe).and_raise(Timeout::Error.new)
      # expect it to get all the way up
      expect { subject.subscribe_to_replies }.to raise_error(Timeout::Error)
    end
  end

  describe '#publish' do
    let(:condition)      { double 'condition', signal: true, wait: false }
    let(:correlation_id) { 'test-correlation-id' }
    let(:properties)     { { correlation_id: correlation_id } }
    let(:request)        { { question: 'gimme the thing' } }
    let(:response)       { { answer: 'the thing you asked for' } }
    let(:routing_key)    { 'routing.key' }
    let(:topic_exchange) { double 'topic exchange' }

    before(:each) do
      allow(channel).to receive(:topic).and_return(topic_exchange)
      allow(reply_to).to receive(:delete)
      allow(reply_to).to receive(:subscribe).and_yield({}, properties, response)
      allow(SecureRandom).to receive(:uuid).and_return(correlation_id)
      allow(subject).to receive(:condition).and_return(condition)
      allow(subject).to receive(:log)
      allow(subject).to receive(:reply_to).and_return(reply_to)
      allow(topic_exchange).to receive(:publish)
    end

    it 'publishes the request on the topic exchange' do
      options = {
        routing_key: routing_key,
        reply_to: reply_to.name,
        persistence: false,
        correlation_id: correlation_id
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

    it 'does not rescue unexpected errors' do
      allow(subject).to receive(:log_request?).and_raise(RuntimeError.new)
      # expect it to get all the way up
      expect { subject.publish request, routing_key }.to raise_error(RuntimeError)
    end

  end # describe '#publish'

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

