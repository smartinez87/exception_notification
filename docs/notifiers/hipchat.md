### HipChat notifier

This notifier sends notifications to your Hipchat room.

#### Usage

Just add the [hipchat](https://github.com/hipchat/hipchat-rb) gem to your `Gemfile`:

```ruby
gem 'hipchat'
```

To configure it, you need to set the `token` and `room_name` options, like this:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        email: {
                                          email_prefix: '[PREFIX] ',
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com}
                                        },
                                        hipchat: {
                                          api_token: 'my_token',
                                          room_name: 'my_room'
                                        }
```

#### Options

##### room_name

*String, required*

The HipChat room where the notifications must be published to.

##### api_token

*String, required*

The API token to allow access to your HipChat account.

##### notify

*Boolean, optional*

Notify users. Default : false.

##### color

*String, optional*

Color of the message. Default : 'red'.

##### from

*String, optional, maximum length : 15*

Message will appear from this nickname. Default : 'Exception'.

##### server_url

*String, optional*

Custom Server URL for self-hosted, Enterprise HipChat Server

For all options & possible values see [Hipchat API](https://www.hipchat.com/docs/api/method/rooms/message).
