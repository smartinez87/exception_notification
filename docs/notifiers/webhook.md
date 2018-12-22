### WebHook notifier

This notifier ships notifications over the HTTP protocol.

#### Usage

Just add the [HTTParty](https://github.com/jnunemaker/httparty) gem to your `Gemfile`:

```ruby
gem 'httparty'
```

To configure it, you need to set the `url` option, like this:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        email: {
                                          email_prefix: '[PREFIX] ',
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com}
                                        },
                                        webhook: {
                                          url: 'http://domain.com:5555/hubot/path'
                                        }
```

By default, the WebhookNotifier will call the URLs using the POST method. But, you can change this using the `http_method` option.

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        email: {
                                          email_prefix: '[PREFIX] ',
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com}
                                        },
                                        webhook: {
                                          url: 'http://domain.com:5555/hubot/path',
                                          http_method: :get
                                        }
```

Besides the `url` and `http_method` options, all the other options are passed directly to HTTParty. Thus, if the HTTP server requires authentication, you can include the following options:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        email: {
                                          email_prefix: '[PREFIX] ',
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com}
                                        },
                                        webhook: {
                                          url: 'http://domain.com:5555/hubot/path',
                                          basic_auth: {
                                            username: 'alice',
                                            password: 'password'
                                          }
                                        }
```

For more HTTParty options, check out the [documentation](https://github.com/jnunemaker/httparty).
