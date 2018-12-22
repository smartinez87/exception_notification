### Mattermost notifier

Post notification in a mattermost channel via [incoming webhook](http://docs.mattermost.com/developer/webhooks-incoming.html)

Just add the [HTTParty](https://github.com/jnunemaker/httparty) gem to your `Gemfile`:

```ruby
gem 'httparty'
```

To configure it, you **need** to set the `webhook_url` option.
You can also specify an other channel with `channel` option.

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        email: {
                                          email_prefix: '[PREFIX] ',
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com}
                                        },
                                        mattermost: {
                                          webhook_url: 'http://your-mattermost.com/hooks/blablabla',
                                          channel: 'my-channel'
                                        }
```

If you are using Github or Gitlab for issues tracking, you can specify `git_url` as follow to add a *Create issue* link in you notification.
By default this will use your Rails application name to match the git repository. If yours differ you can specify `app_name`.


```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        email: {
                                          email_prefix: '[PREFIX] ',
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com}
                                        },
                                        mattermost: {
                                          webhook_url: 'http://your-mattermost.com/hooks/blablabla',
                                          git_url: 'github.com/aschen'
                                        }
```

You can also specify the bot name and avatar with `username` and `avatar` options.

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        email: {
                                          email_prefix: 'PREFIX] ',
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com}
                                        },
                                        mattermost: {
                                          webhook_url: 'http://your-mattermost.com/hooks/blablabla',
                                          avatar: 'http://example.com/your-image.png',
                                          username: 'Fail bot'
                                        }
```

Finally since the notifier use HTTParty, you can include all HTTParty options, like basic_auth for example.

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        email: {
                                          email_prefix: '[PREFIX] ',
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com}
                                        },
                                        mattermost: {
                                          webhook_url: 'http://your-mattermost.com/hooks/blablabla',
                                          basic_auth: {
                                            username: 'clara',
                                            password: 'password'
                                          }
                                        }
```

#### Options

##### webhook_url

*String, required*

The Incoming WebHook URL on mattermost.

##### channel

*String, optional*

Message will appear in this channel. Defaults to the channel you set as such on mattermost.

##### username

*String, optional*

Username of the bot. Defaults to "Incoming Webhook"

##### avatar

*String, optional*

Avatar of the bot. Defaults to incoming webhook icon.

##### git_url

*String, optional*

Url of your gitlab or github with your organisation name for issue creation link (Eg: `github.com/aschen`). Defaults to nil and don't add link to the notification.

##### app_name

*String, optional*

Your application name used for issue creation link. Defaults to ```Rails.application.class.parent_name.underscore```.
