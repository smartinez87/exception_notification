### Teams notifier

Post notification in a Microsoft Teams channel via [Incoming Webhook Connector](https://docs.microsoft.com/en-us/outlook/actionable-messages/actionable-messages-via-connectors)
Just add the [HTTParty](https://github.com/jnunemaker/httparty) gem to your `Gemfile`:

```ruby
gem 'httparty'
```

To configure it, you **need** to set the `webhook_url` option.
If you are using GitLab for issue tracking, you can specify `git_url` as follows to add a *Create issue* button in your notification.
By default this will use your Rails application name to match the git repository. If yours differs, you can specify `app_name`.
By that same notion, you may also set a `jira_url` to get a button that will send you to the New Issue screen in Jira.

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  email: {
    email_prefix: "[PREFIX] ",
    sender_address: %{"notifier" <notifier@example.com>},
    exception_recipients: %w{exceptions@example.com}
  },
  teams: {
    webhook_url: 'https://outlook.office.com/webhook/your-guid/IncomingWebhook/team-guid',
    git_url: 'https://your-gitlab.com/Group/Project',
    jira_url: 'https://your-jira.com'
  }
```

#### Options

##### webhook_url

*String, required*

The Incoming WebHook URL on Teams.

##### git_url

*String, optional*

Url of your gitlab or github with your organisation name for issue creation link (Eg: `github.com/aschen`). Defaults to nil and doesn't add link to the notification.

##### jira_url

*String, optional*

Url of your Jira instance, adds button for Create Issue screen. Defaults to nil and doesn't add a button to the card.

##### app_name

*String, optional*

Your application name used for git issue creation link. Defaults to `Rails.application.class.parent_name.underscore`.
