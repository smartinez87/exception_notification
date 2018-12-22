### Google Chat Notifier

Post notifications in a Google Chats channel via [incoming webhook](https://developers.google.com/hangouts/chat/how-tos/webhooks)

Add the [HTTParty](https://github.com/jnunemaker/httparty) gem to your `Gemfile`:

```ruby
gem 'httparty'
```

To configure it, you **need** to set the `webhook_url` option.

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  google_chat: {
    webhook_url: 'https://chat.googleapis.com/v1/spaces/XXXXXXXX/messages?key=YYYYYYYYYYYYY&token=ZZZZZZZZZZZZ'
  }
```

##### webhook_url

*String, required*

The Incoming WebHook URL on Google Chats.

##### app_name

*String, optional*

Your application name, shown in the notification. Defaults to `Rails.application.class.parent_name.underscore`.
