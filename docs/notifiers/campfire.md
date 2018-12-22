### Campfire notifier

This notifier sends notifications to your Campfire room.

#### Usage

Just add the [tinder](https://github.com/collectiveidea/tinder) gem to your `Gemfile`:

```ruby
gem 'tinder'
```

To configure it, you need to set the `subdomain`, `token` and `room_name` options, like this:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        email: {
                                          email_prefix: '[PREFIX] ',
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com}
                                        },
                                        campfire: {
                                          subdomain: 'my_subdomain',
                                          token: 'my_token',
                                          room_name: 'my_room'
                                        }
```

#### Options

##### subdomain

*String, required*

Your subdomain at Campfire.

##### room_name

*String, required*

The Campfire room where the notifications must be published to.

##### token

*String, required*

The API token to allow access to your Campfire account.


For more options to set Campfire, like _ssl_, check [here](https://github.com/collectiveidea/tinder/blob/master/lib/tinder/campfire.rb#L17).
