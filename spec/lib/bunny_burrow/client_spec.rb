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


  end # describe 'instance'

  describe '#publish' do
    let(:condition)      { double 'condition', signal: true, wait: false }
    let(:request)        { { question: 'gimme the thing' } }
    let(:response)       { { answer: 'the thing you asked for' } }
    let(:routing_key)    { 'routing.key' }
    let(:topic_exchange) { double 'topic exchange' }

    before(:each) do
      allow(channel).to receive(:topic).and_return(topic_exchange)
      allow(reply_to).to receive(:subscribe).and_yield({}, {}, response)
      allow(subject).to receive(:condition).and_return(condition)
      allow(subject).to receive(:log)
      allow(channel).to receive(:queue).with("", {:exclusive=>true, :auto_delete=>true}).and_return(reply_to)
      allow(topic_exchange).to receive(:publish)
    end

    it 'publishes the request on the topic exchange' do
      options = {
        routing_key: routing_key,
        reply_to: reply_to.name,
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

    it 'creates a reply-to queue ' do
      options = {
        exclusive: true,
        auto_delete: true
      }
      expect(channel).to receive(:queue).with('', hash_including(options))
      subject.publish request, routing_key
    end

    it 'subscribes to the reply-to queue' do
      expect(reply_to).to receive(:subscribe)
      subject.publish request, routing_key
    end

    it 'logs receiving details without the response' do
      allow(subject).to receive(:log_response?).and_return(false)
      expect(subject).to receive(:log).with(/^Receiving(?!.*response).*/)
      subject.publish request, routing_key
    end

    it 'logs receiving details with the response' do
      allow(subject).to receive(:log_response?).and_return(true)
      expect(subject).to receive(:log).with(/^Receiving(?=.*response).*/)
      subject.publish request, routing_key
    end

    it 'returns the response' do
      allow(subject).to receive(:timeout).and_return(5)
      result = subject.publish(request, routing_key)
      expect(result).to eq(response)
    end

    it 'does not rescue timeout errors' do
      allow(reply_to).to receive(:subscribe).and_raise(Timeout::Error.new)
      # expect it to get all the way up
      expect { subject.publish request, routing_key }.to raise_error(Timeout::Error)
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

