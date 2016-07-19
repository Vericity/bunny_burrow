require 'spec_helper'

describe BunnyBurrow::Base do
  let(:tls_cert)     { 'tls-cert' }
  let(:tls_key)      { 'tls-key' }
  let(:tls_ca_certs) { [ 'tls-ca-cert' ] }

  subject { described_class.new }

  describe 'default initialization' do
    it 'yields if a block is given' do
      expect { |b| described_class.new &b }.to yield_control
    end

    it 'does not yield if a block is not given' do
      allow_any_instance_of(BunnyBurrow::Base).to receive(:block_given?).and_return(false)
      expect { |b| described_class.new &b }.to_not yield_control
    end

    it 'defaults timeout to 60' do
      expect(subject.timeout).to eq(60)
    end

    it 'defaults log_request to false' do
      expect(subject.log_request?).to be_falsey
    end

    it 'defaults log_response to false' do
      expect(subject.log_response?).to be_falsey
    end

    it 'defaults verify_peer to true' do
      expect(subject.verify_peer?).to be true
    end
  end # describe 'default initialization'

  describe 'custom initialization' do
    let(:rabbitmq_url)      { 'rabbitmq-url' }
    let(:rabbitmq_exchange) { 'rabbitmq-exchange' }
    let(:logger)            { instance_double 'Logger' }
    let(:log_prefix)        { 'log-prefix' }
    let(:timeout)           { rand(60) + 1 }

    subject do
      described_class.new do |dc|
        dc.rabbitmq_url = rabbitmq_url
        dc.rabbitmq_exchange = rabbitmq_exchange
        dc.logger = logger
        dc.log_prefix = log_prefix
        dc.timeout = timeout
        dc.log_request = true
        dc.log_response = true
        dc.verify_peer = false
        dc.tls_cert = tls_cert
        dc.tls_key = tls_key
        dc.tls_ca_certs = tls_ca_certs
      end
    end

    it 'allows rabbitmq_url to be set' do
      expect(subject.rabbitmq_url).to eq(rabbitmq_url)
    end

    it 'allows rabbitmq_exchange to be set' do
      expect(subject.rabbitmq_exchange).to eq(rabbitmq_exchange)
    end

    it 'allows logger to be set' do
      expect(subject.logger).to eq(logger)
    end

    it 'allows log_prefix to be set' do
      expect(subject.log_prefix).to eq(log_prefix)
    end

    it 'allows timeout to be set' do
      expect(subject.timeout).to eq(timeout)
    end

    it 'allows log_request to be set' do
      expect(subject.log_request?).to be_truthy
    end

    it 'allows log_response to be set' do
      expect(subject.log_response?).to be_truthy
    end

    it 'allows verify_peer to be set' do
      expect(subject.verify_peer?).to be_falsey
    end

    it 'allows tls_cert to be set' do
      expect(subject.tls_cert).to eq(tls_cert)
    end

    it 'allows tls_key to be set' do
      expect(subject.tls_key).to eq(tls_key)
    end

    it 'allows tls_ca_certs to be set' do
      expect(subject.tls_ca_certs).to eq(tls_ca_certs)
    end
  end # describe 'custom initialization'

  describe 'instance' do
    let(:channel)            { double 'channel' }
    let(:condition)          { double 'ConditionVariable' }
    let(:connection)         { double 'Bunny' }
    let(:default_exchange)   { double 'default exchange' }
    let(:default_log_level)  { :info }
    let(:default_log_prefix) { 'BunnyBurrow' }
    let(:lock)               { double 'Mutex' }
    let(:logger)             { double 'Logger' }
    let(:message)            { 'some log message' }
    let(:topic_exchange)     { double 'topic exchange' }

    describe '#connection' do
      before(:each) do
        subject.instance_variable_set('@connection', nil)
        allow(subject).to receive(:tls_cert).and_return(tls_cert)
        allow(subject).to receive(:tls_key).and_return(tls_key)
        allow(subject).to receive(:tls_ca_certs).and_return(tls_ca_certs)
        allow(subject).to receive(:verify_peer?).and_return(true)
        allow(connection).to receive(:start)
        allow(Bunny).to receive(:new).and_return(connection)
      end

      it 'creates a connection when one does not exist' do
        expect(Bunny).to receive(:new)
        subject.send :connection
      end

      it 'sets verify_peer to true by default' do
        expect(Bunny).to receive(:new).with(anything, hash_including(verify_peer: true))
        subject.send :connection
      end

      it 'can set verify_peer to false' do
        allow(subject).to receive(:verify_peer?).and_return(false)
        expect(Bunny).to receive(:new).with(anything, hash_including(verify_peer: false))
        subject.send :connection
      end

      it 'sets tls_cert when present' do
        expect(Bunny).to receive(:new).with(anything, hash_including(tls_cert: tls_cert))
        subject.send :connection
      end

      it 'does not set tls_cert when not present' do
        allow(subject).to receive(:tls_cert).and_return(nil)
        expect(Bunny).to receive(:new).with(anything, hash_excluding(tls_cert: tls_cert))
        subject.send :connection
      end

      it 'sets tls_key when present' do
        expect(Bunny).to receive(:new).with(anything, hash_including(tls_key: tls_key))
        subject.send :connection
      end

      it 'does not set tls_key when not present' do
        allow(subject).to receive(:tls_key).and_return(nil)
        expect(Bunny).to receive(:new).with(anything, hash_excluding(tls_key: tls_key))
        subject.send :connection
      end

      it 'sets tls_ca_certs when present' do
        expect(Bunny).to receive(:new).with(anything, hash_including(tls_ca_certs: tls_ca_certs))
        subject.send :connection
      end

      it 'does not set tls_ca_certs when not present' do
        allow(subject).to receive(:tls_ca_certs).and_return(nil)
        expect(Bunny).to receive(:new).with(anything, hash_excluding(tls_ca_certs: tls_ca_certs))
        subject.send :connection
      end

      it 'starts the connection' do
        expect(connection).to receive(:start)
        subject.send :connection
      end

      it 'uses an existing connection' do
        subject.instance_variable_set('@connection', connection)
        expect(Bunny).not_to receive(:new)
        expect(connection).not_to receive(:start)
        subject.send :connection
      end
    end # describe '#connection'

    describe '#channel' do
      before(:each) do
        allow(subject).to receive(:connection).and_return(connection)
        subject.instance_variable_set('@channel', nil)
      end

      it 'creates a channel when one does not exist' do
        expect(connection).to receive(:create_channel)
        subject.send :channel
      end

      it 'uses an existing channel' do
        subject.instance_variable_set('@channel', channel)
        expect(connection).not_to receive(:create_channel)
        subject.send :channel
      end
    end # describe '#channel'

    describe '#default_exchange' do
      before(:each) do
        allow(subject).to receive(:channel).and_return(channel)
        allow(channel).to receive(:default_exchange)
        subject.instance_variable_set('@default_exchange', nil)
      end

      it 'creates a default exchange when one does not exist' do
        expect(channel).to receive(:default_exchange)
        subject.send :default_exchange
      end

      it 'uses an existing default exchange' do
        subject.instance_variable_set('@default_exchange', default_exchange)
        expect(channel).not_to receive(:default_exchange)
        subject.send :default_exchange
      end
    end # describe '#default_exchange'

    describe '#topic_exchange' do
      before(:each) do
        allow(subject).to receive(:channel).and_return(channel)
        allow(channel).to receive(:topic)
        subject.instance_variable_set('@topic_exchange', nil)
      end

      it 'creates a topic exchange when one does not exist' do
        expect(channel).to receive(:topic)
        subject.send :topic_exchange
      end

      it 'uses an existing topic exchange' do
        subject.instance_variable_set('@topic_exchange', topic_exchange)
        expect(channel).not_to receive(:topic)
        subject.send :topic_exchange
      end
    end # describe '#topic_exchange'

    describe '#lock' do
      it 'creates a lock when one does not exist' do
        subject.instance_variable_set('@lock', nil)
        expect(Mutex).to receive(:new)
        subject.send :lock
      end

      it 'uses an existing lock' do
        subject.instance_variable_set('@lock', lock)
        expect(Mutex).not_to receive(:new)
        subject.send :lock
      end
    end # describe '#lock'

    describe '#condition' do
      it 'creates a condition when one does not exist' do
        subject.instance_variable_set('@condition', nil)
        expect(ConditionVariable).to receive(:new)
        subject.send :condition
      end

      it 'uses an existing condition variable' do
        subject.instance_variable_set('@condition', condition)
        expect(ConditionVariable).not_to receive(:new)
        subject.send :condition
      end
    end # describe '#condition'

    describe '#log' do
      before(:each) do
        allow(subject).to receive(:logger).and_return(logger)
      end

      it 'does not log if no logger' do
        allow(subject).to receive(:logger).and_return(nil)
        expect { subject.send :log, message }.not_to raise_error
      end

      it 'logs when there is a logger' do
        expect(logger).to receive(default_log_level)
        subject.send :log, message
      end

      it 'defaults log prefix' do
        expect(logger).to receive(default_log_level).with("#{default_log_prefix}: #{message}")
        subject.send :log, message
      end

      it 'uses configured log prefix' do
        log_prefix = 'Flibby'
        allow(subject).to receive(:log_prefix).and_return(log_prefix)
        expect(logger).to receive(default_log_level).with("#{log_prefix}: #{message}")
        subject.send :log, message
      end

      it 'defaults log level to :info' do
        expect(logger).to receive(default_log_level)
        subject.send :log, message
      end

      it 'allows other log levels' do
        log_level = :warn
        expect(logger).to receive(log_level)
        subject.send :log, message, level: log_level
      end
    end # describe '#log'
  end # describe 'instance'
end
