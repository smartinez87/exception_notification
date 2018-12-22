### Slack notifier

This notifier sends notifications to a slack channel using the slack-notifier gem.

#### Usage

Just add the [slack-notifier](https://github.com/stevenosloan/slack-notifier) gem to your `Gemfile`:

```ruby
gem 'slack-notifier'
```

To configure it, you need to set at least the 'webhook_url' option, like this:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        email: {
                                          email_prefix: '[PREFIX] ',
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com}
                                        },
                                        slack: {
                                          webhook_url: '[Your webhook url]',
                                          channel: '#exceptions',
                                          additional_parameters: {
                                            icon_url: 'http://image.jpg',
                                            mrkdwn: true
                                          }
                                        }
```

The slack notification will include any data saved under `env['exception_notifier.exception_data']`.

An example of how to send the server name to Slack in Rails (put this code in application_controller.rb):

```ruby
before_action :set_notification

def set_notification
  request.env['exception_notifier.exception_data'] = { 'server' => request.env['SERVER_NAME'] }
  # can be any key-value pairs
end
```

If you find this too verbose, you can determine to exclude certain information by doing the following:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        slack: {
                                          webhook_url: '[Your webhook url]',
                                          channel: '#exceptions',
                                          additional_parameters: {
                                            icon_url: 'http://image.jpg',
                                            mrkdwn: true
                                          },
                                          ignore_data_if: lambda {|key, value|
                                            "#{key}" == 'key_to_ignore' || value.is_a?(ClassToBeIgnored)
                                          }
                                        }
```

Any evaluation to `true` will cause the key / value pair not be be sent along to Slack.

#### Options

##### webhook_url

*String, required*

The Incoming WebHook URL on slack.

##### channel

*String, optional*

Message will appear in this channel. Defaults to the channel you set as such on slack.

##### username

*String, optional*

Username of the bot. Defaults to the name you set as such on slack

##### custom_hook

*String, optional*

Custom hook name. See [slack-notifier](https://github.com/stevenosloan/slack-notifier#custom-hook-name) for
more information. Default: 'incoming-webhook'

##### additional_parameters

*Hash of strings, optional*

Contains additional payload for a message (e.g avatar, attachments, etc). See [slack-notifier](https://github.com/stevenosloan/slack-notifier#additional-parameters) for more information.. Default: '{}'

##### additional_fields

*Array of Hashes, optional*

Contains additional fields that will be added to the attachement. See [Slack documentation](https://api.slack.com/docs/message-attachments).
