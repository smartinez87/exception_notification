### IRC notifier

This notifier sends notifications to an IRC channel using the carrier-pigeon gem.

#### Usage

Just add the [carrier-pigeon](https://github.com/portertech/carrier-pigeon) gem to your `Gemfile`:

```ruby
gem 'carrier-pigeon'
```

To configure it, you need to set at least the 'domain' option, like this:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        email: {
                                          email_prefix: '[PREFIX] ',
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com}
                                        },
                                        irc: {
                                          domain: 'irc.example.com'
                                        }
```

There are several other options, which are described below. For example, to use ssl and a password, add a prefix, post to the '#log' channel, and include recipients in the message (so that they will be notified), your configuration might look like this:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        irc: {
                                          domain: 'irc.example.com',
                                          nick: 'BadNewsBot',
                                          password: 'secret',
                                          port: 6697,
                                          channel: '#log',
                                          ssl: true,
                                          prefix: '[Exception Notification]',
                                          recipients: ['peter', 'michael', 'samir']
                                        }
```

#### Options

##### domain

*String, required*

The domain name of your IRC server.

##### nick

*String, optional*

The message will appear from this nick. Default : 'ExceptionNotifierBot'.

##### password

*String, optional*

Password for your IRC server.

##### port

*String, optional*

Port your IRC server is listening on. Default : 6667.

##### channel

*String, optional*

Message will appear in this channel. Default : '#log'.

##### notice

*Boolean, optional*

Send a notice. Default : false.

##### ssl

*Boolean, optional*

Whether to use SSL. Default : false.

##### join

*Boolean, optional*

Join a channel. Default : false.

##### recipients

*Array of strings, optional*

Nicks to include in the message. Default: []
