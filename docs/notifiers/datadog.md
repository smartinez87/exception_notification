### Datadog notifier

This notifier sends error events to Datadog using the [Dogapi](https://github.com/DataDog/dogapi-rb) gem.

#### Usage

Just add the [Dogapi](https://github.com/DataDog/dogapi-rb) gem to your `Gemfile`:

```ruby
gem 'dogapi'
```

To use datadog notifier, you first need to create a `Dogapi::Client` with your datadog api and application keys, like this:

```ruby
client = Dogapi::Client.new(api_key, application_key)
```

You then need to set the `client` option, like this:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  email: {
    email_prefix: "[PREFIX] ",
    sender_address: %{"notifier" <notifier@example.com>},
    exception_recipients: %w{exceptions@example.com}
  },
  datadog: {
    client: client
  }
```

#### Options

##### client

*DogApi::Client, required*

The API client to send events to Datadog.

##### title_prefix

*String, optional*

Prefix for event title in Datadog.

##### tags

*Array of Strings, optional*

Optional tags for events in Datadog.
