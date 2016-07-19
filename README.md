# BunnyBurrow

[![Build Status](https://travis-ci.org/johann-koebbe/bunny_burrow.svg)](http://travis-ci.org/johann-koebbe/bunny_burrow)

BunnyBurrow is a simple approach to RPC over RabbitMQ via the Bunny gem.
A 'server' application listens on one ore more queues on a topic exchange
while a 'client' publishes to a single queue on the same exchange.
BunnyBurrow will do all of the dirty work of establishing a connection to
RabbitMQ, opening the channel, ensuring the exchange and queue(s) exist,
and sending the payloads back and forth. All you have to do is decide what
to do on each end. BunnyBurrow even cleans up after itself so there aren't
a bunch of queues and connections left laying around after they are no
longer needed.

Why 'burrow'?

burrow (noun)
1. a hole or tunnel dug by a small animal, especially a rabbit, as a dwelling.
   synonyms: hole, tunnel, warren, dugout

burrow (verb)
1. (of an animal) make a hole or tunnel, especially to use as a dwelling.
   synonyms:  tunnel, dig (out), excavate, grub, mine, bore, channel

The idea that _a_ burrow is a tunnel (or channel) and _to_ burrow is to
make a tunnel (or channel) seemed to fit very nicely with what the gem does.
Well, that and 'bunny_rpc' was already taken ;)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'bunny_burrow'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install bunny_burrow

## Usage

There are templates you can use to get started quickly (or just see how
BunnyBurrow is used) in the `templates` directory of the repository. But a
very simple server can be made with

```ruby
require 'bunny_burrow'

rpc_server = BunnyBurrow::Server.new do |server|
  server.rabbitmq_url = 'amqp://user:pass@server[:port]/vhost'
  server.rabbitmq_exchange = 'bunny_exchange'
  server.logger = Logger.new(STDOUT)
end

rpc_server.subscribe('some.routing.key') do |payload|
  response = BunnyBurrow::Server.create_response
  response[:data] = do_something_with(payload)

  # return the response
  response
end

# can subscribe to multiple queues
rpc_server.subscribe('some.other.routing.key') do |payload|
  response = BunnyBurrow::Server.create_response
  response[:data] = do_something_else_with(payload)

  # return the response
  response
end

# tell the server to keep the process alive so it can receive messages
rpc_server.wait

# at some later point, stop waiting and close connections
rpc_server.shutdown
```

A client is equally as easy to implement:

```ruby
require 'bunny_burrow'

rpc_client = BunnyBurrow::Client.new do |client|
  client.rabbitmq_url = 'amqp://user:pass@server[:port]/vhost'
  client.rabbitmq_exchange = 'bunny_exchange'
  client.logger = Logger.new(STDOUT)
end

payload = { question: 'the thing you want' }

# the rpc_client will wait for a response from the server
# (this _is_ RPC, after all ;) )
result = rpc_client.publish(payload, 'some.routing.key')
puts result

# some time later, close connections
rpc_client.shutdown
```

Using the templates is also easy:

```
$ cd /path/to/development/work
$ git init my_rpc_server
$ cd my_rpc_server
$ cp /path/to/bunny_burrow/repo/templates/Gemfile .
$ cp -R /path/to/bunny_burrow/repo/templates/server/* .
$ grep -r your_project . | cut -d : -f 1 | xargs sed -i '' 's/your_project/my_rpc_server/'
$ grep -r YourProject . | cut -d : -f 1 | xargs sed -i '' 's/YourProject/MyRPCServer/'
$ mv lib/your_project lib/my_rpc_server
```

Edit the Gemfile and template files as appropriate, then

```
$ bundle install [--path vendor/bundle]
$ git add .
$ git commit -m 'Initial commit.'
```

## Notes

The templates may not be suitable for everyone. Be sure to inspect them and remove anything
that does not apply to your project.

Due to the locking implementation in `BunnyBurrow::Client#publish`, there is the potential for a
deadlock if the same client is used to publish on separate threads. If that behavior is
desired, `publish` will need to be changed to use a dedicated mutex.

## Development

After checking out the repo, run `bundle install [--path vendor/bundle]` to install dependencies.
Then, run `bundle exec rspec` to run the tests.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/johann-koebbe/bunny_burrow.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

