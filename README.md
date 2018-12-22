# Exception Notification

[![Gem Version](https://fury-badge.herokuapp.com/rb/exception_notification.png)](http://badge.fury.io/rb/exception_notification)
[![Travis](https://api.travis-ci.org/smartinez87/exception_notification.png)](http://travis-ci.org/smartinez87/exception_notification)
[![Coverage Status](https://coveralls.io/repos/smartinez87/exception_notification/badge.png?branch=master)](https://coveralls.io/r/smartinez87/exception_notification)
[![Code Climate](https://codeclimate.com/github/smartinez87/exception_notification.png)](https://codeclimate.com/github/smartinez87/exception_notification)

**THIS README IS FOR THE MASTER BRANCH AND REFLECTS THE WORK CURRENTLY EXISTING ON THE MASTER BRANCH. IF YOU ARE WISHING TO USE A NON-MASTER BRANCH OF EXCEPTION NOTIFICATION, PLEASE CONSULT THAT BRANCH'S README AND NOT THIS ONE.**

---

The Exception Notification gem provides a set of [notifiers](#notifiers) for sending notifications when errors occur in a Rack/Rails application. The built-in notifiers can deliver notifications by [email](docs/notifiers/email.md), [Campfire](docs/notifiers/campfire.md), [HipChat](docs/notifiers/hipchat.md), [Slack](docs/notifiers/slack.md), [Rocket.Chat notifier](docs/notifiers/rocket_chat.md), [Mattermost](docs/notifiers/mattermost.md), [Teams](docs/notifiers/teams.md), [IRC](docs/notifiers/irc.md), [Amazon SNS](docs/notifiers/sns.md), [Google Chat](docs/notifiers/google_chat.md), [Datadog](docs/notifiers/datadog.md) or via custom [WebHooks](docs/notifiers/webhook.md).

There's a great [Railscast about Exception Notification](http://railscasts.com/episodes/104-exception-notifications-revised) you can see that may help you getting started.

[Follow us on Twitter](https://twitter.com/exception_notif) to get updates and notices about new releases.

## Requirements

* Ruby 2.0 or greater
* Rails 4.0 or greater, Sinatra or another Rack-based application.

For previous releases, please checkout [this](#versions).

## Getting Started

Add the following line to your application's Gemfile:

```ruby
gem 'exception_notification'
```

### Rails

ExceptionNotification is used as a rack middleware, or in the environment you want it to run. In most cases you would want ExceptionNotification to run on production. Thus, you can make it work by putting the following lines in your `config/environments/production.rb`:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  email: {
    deliver_with: :deliver, # Rails >= 4.2.1 do not need this option since it defaults to :deliver_now
    email_prefix: '[PREFIX] ',
    sender_address: %{"notifier" <notifier@example.com>},
    exception_recipients: %w{exceptions@example.com}
  }
```

**Note**: In order to enable delivery notifications by email make sure you have [ActionMailer configured](docs/notifiers/email.md#actionmailer-configuration).

### Rack/Sinatra

In order to use ExceptionNotification with Sinatra, please take a look in the [example application](https://github.com/smartinez87/exception_notification/tree/master/examples/sinatra).

### Custom Data, e.g. Current User

Save the current user in the `request` using a controller callback.

```ruby
class ApplicationController < ActionController::Base
  before_action :prepare_exception_notifier

  private

  def prepare_exception_notifier
    request.env["exception_notifier.exception_data"] = {
      current_user: current_user
    }
  end
end
```

The current user will show up in your email, in a new section titled "Data".

```
------------------------------- Data:

* data: {:current_user=>
  #<User:0x007ff03c0e5860
   id: 3,
   email: "jane.doe@example.com", # etc...
```

For more control over the display of custom data, see "Email notifier ->
Options -> sections" below.

## Notifiers

ExceptionNotification relies on notifiers to deliver notifications when errors occur in your applications. By default, 12 notifiers are available:

* [Campfire notifier](docs/notifiers/campfire.md)
* [Datadog notifier](docs/notifiers/datadog.md)
* [Email notifier](docs/notifiers/email.md)
* [HipChat notifier](docs/notifiers/hipchat.md)
* [IRC notifier](docs/notifiers/irc.md)
* [Slack notifier](docs/notifiers/slack.md)
* [Rocket.Chat notifier](#rocketchat-notifier)
* [Mattermost notifier](docs/notifiers/mattermost.md)
* [Teams notifier](docs/notifiers/teams.md)
* [Amazon SNS](docs/notifiers/sns.md)
* [Google Chat notifier](docs/notifiers/google_chat.md)
* [WebHook notifier](docs/notifiers/webhook.md)

But, you also can easily implement your own [custom notifier](docs/notifiers/custom.md).

## Error Grouping
In general, exception notification will send every notification when an error occured, which may result in a problem: if your site has a high throughput and an same error raised frequently, you will receive too many notifications during a short period time, your mail box may be full of thousands of exception mails or even your mail server will be slow. To prevent this, you can choose to error errors by using `:error_grouping` option and set it to `true`.

Error grouping has a default formula `log2(errors_count)` to determine if it is needed to send the notification based on the accumulated errors count for specified exception, this makes the notifier only send notification when count is: 1, 2, 4, 8, 16, 32, 64, 128, ... (2**n). You can use `:notification_trigger` to override this default formula.

The below shows options used to enable error grouping:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  ignore_exceptions: ['ActionView::TemplateError'] + ExceptionNotifier.ignored_exceptions,
  email:  {
    email_prefix: '[PREFIX] ',
    sender_address: %{"notifier" <notifier@example.com>},
    exception_recipients: %w{exceptions@example.com}
  },
  error_grouping: true,
  # error_grouping_period: 5.minutes,    # the time before an error is regarded as fixed
  # error_grouping_cache: Rails.cache,   # for other applications such as Sinatra, use one instance of ActiveSupport::Cache::Store
  #
  # notification_trigger: specify a callback to determine when a notification should be sent,
  #   the callback will be invoked with two arguments:
  #     exception: the exception raised
  #     count: accumulated errors count for this exception
  #
  # notification_trigger: lambda { |exception, count| count % 10 == 0 }
```

## Ignore Exceptions

You can choose to ignore certain exceptions, which will make ExceptionNotification avoid sending notifications for those specified. There are three ways of specifying which exceptions to ignore:

* `:ignore_exceptions` - By exception class (i.e. ignore RecordNotFound ones)

* `:ignore_crawlers`   - From crawler (i.e. ignore ones originated by Googlebot)

* `:ignore_if`         - Custom (i.e. ignore exceptions that satisfy some condition)


### :ignore_exceptions

*Array of strings, default: %w{ActiveRecord::RecordNotFound Mongoid::Errors::DocumentNotFound AbstractController::ActionNotFound ActionController::RoutingError ActionController::UnknownFormat}*

Ignore specified exception types. To achieve that, you should use the `:ignore_exceptions` option, like this:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        ignore_exceptions: ['ActionView::TemplateError'] + ExceptionNotifier.ignored_exceptions,
                                        email: {
                                          email_prefix: '[PREFIX] ',
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com}
                                        }
```

The above will make ExceptionNotifier ignore a *TemplateError* exception, plus the ones ignored by default.

### :ignore_crawlers

*Array of strings, default: []*

In some cases you may want to avoid getting notifications from exceptions made by crawlers. To prevent sending those unwanted notifications, use the `:ignore_crawlers` option like this:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        ignore_crawlers: %w{Googlebot bingbot},
                                        email: {
                                          email_prefix: '[PREFIX] ',
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com}
                                        }
```

### :ignore_if

*Lambda, default: nil*

Last but not least, you can ignore exceptions based on a condition. Take a look:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        ignore_if: ->(env, exception) { exception.message =~ /^Couldn't find Page with ID=/ },
                                        email: {
                                          email_prefix: '[PREFIX] ',
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com},
                                        }
```

You can make use of both the environment and the exception inside the lambda to decide wether to avoid or not sending the notification.

## Rack X-Cascade Header

Some rack apps (Rails in particular) utilize the "X-Cascade" header to pass the request-handling responsibility to the next middleware in the stack.

Rails' routing middleware uses this strategy, rather than raising an exception, to handle routing errors (e.g. 404s); to be notified whenever a 404 occurs, set this option to "false."

### :ignore_cascade_pass

*Boolean, default: true*

Set to false to trigger notifications when another rack middleware sets the "X-Cascade" header to "pass."

## Background Notifications

If you want to send notifications from a background process like DelayedJob, you should use the `notify_exception` method like this:

```ruby
begin
  some code...
rescue => e
  ExceptionNotifier.notify_exception(e)
end
```

You can include information about the background process that created the error by including a data parameter:

```ruby
begin
  some code...
rescue => e
  ExceptionNotifier.notify_exception(
    e,
    data: { worker: worker.to_s, queue: queue, payload: payload}
  )
end
```

### Manually notify of exception

If your controller action manually handles an error, the notifier will never be run. To manually notify of an error you can do something like the following:

```ruby
rescue_from Exception, with: :server_error

def server_error(exception)
  # Whatever code that handles the exception

  ExceptionNotifier.notify_exception(
    exception,
    env: request.env, data: { message: 'was doing something wrong' }
  )
end
```


## Extras

### Rails

Since his first version, ExceptionNotification was just a simple rack middleware. But, the version 4.0.0 introduced the option to use it as a Rails engine. In order to use ExceptionNotification as an engine, just run the following command from the terminal:

    rails g exception_notification:install

This command generates an initialize file (`config/initializers/exception_notification.rb`) where you can customize your configurations.

Make sure the gem is not listed solely under the `production` group, since this initializer will be loaded regardless of environment.

### Resque/Sidekiq

Instead of manually calling background notifications foreach job/worker, you can configure ExceptionNotification to do this automatically. For this, run:

    rails g exception_notification:install --resque

or

    rails g exception_notification:install --sidekiq

As above, make sure the gem is not listed solely under the `production` group, since this initializer will be loaded regardless of environment.

## Versions

For v4.2.1, see this tag:

http://github.com/smartinez87/exception_notification/tree/v4.2.1

For v4.2.0, see this tag:

http://github.com/smartinez87/exception_notification/tree/v4.2.0

For previous releases, visit:

https://github.com/smartinez87/exception_notification/tags

If you are running Rails 2.3 then see the branch for that:

http://github.com/smartinez87/exception_notification/tree/2-3-stable

If you are running pre-rack Rails then see this tag:

http://github.com/smartinez87/exception_notification/tree/pre-2-3


## Support and tickets

Here's the list of [issues](https://github.com/smartinez87/exception_notification/issues) we're currently working on.

To contribute, please read first the [Contributing Guide](https://github.com/smartinez87/exception_notification/blob/master/CONTRIBUTING.md).

## Code of Conduct

Everyone interacting in this project's codebases, issue trackers, chat rooms, and mailing lists is expected to follow our [code of conduct](https://github.com/smartinez87/exception_notification/blob/master/CODE_OF_CONDUCT.md).

## License

Copyright (c) 2005 Jamis Buck, released under the [MIT license](http://www.opensource.org/licenses/MIT).
