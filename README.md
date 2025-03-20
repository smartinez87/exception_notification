# Exception Notification

[![Gem Version](https://badge.fury.io/rb/exception_notification.svg)](https://badge.fury.io/rb/exception_notification)
[![Build Status](https://github.com/smartinez87/exception_notification/actions/workflows/main.yml/badge.svg)](https://github.com/smartinez87/exception_notification/actions/workflows/main.yml)
[![Coverage Status](https://coveralls.io/repos/github/smartinez87/exception_notification/badge.svg?branch=master)](https://coveralls.io/github/smartinez87/exception_notification?branch=master)
[![Maintainability](https://api.codeclimate.com/v1/badges/78a9a12be00a6d305136/maintainability)](https://codeclimate.com/github/smartinez87/exception_notification/maintainability)

**THIS README IS FOR THE MASTER BRANCH AND REFLECTS THE WORK CURRENTLY EXISTING ON THE MASTER BRANCH. IF YOU ARE WISHING TO USE A NON-MASTER BRANCH OF EXCEPTION NOTIFICATION, PLEASE CONSULT THAT BRANCH'S README AND NOT THIS ONE.**

---

The Exception Notification gem provides a set of [notifiers](#notifiers) for sending notifications when errors occur in a Rack/Rails application. The built-in notifiers can deliver notifications by [email](docs/notifiers/email.md), [HipChat](docs/notifiers/hipchat.md), [Slack](docs/notifiers/slack.md), [Mattermost](docs/notifiers/mattermost.md), [Teams](docs/notifiers/teams.md), [IRC](docs/notifiers/irc.md), [Amazon SNS](docs/notifiers/sns.md), [Google Chat](docs/notifiers/google_chat.md), [Datadog](docs/notifiers/datadog.md) or via custom [WebHooks](docs/notifiers/webhook.md).

There's a great [Railscast about Exception Notification](http://railscasts.com/episodes/104-exception-notifications-revised) you can see that may help you getting started.

[Follow us on Twitter](https://twitter.com/exception_notif) to get updates and notices about new releases.

## Requirements

* Ruby 2.5 or greater
* Rails 5.2 or greater, Sinatra or another Rack-based application.

## Getting Started

Add the following line to your application's Gemfile:

```ruby
gem 'exception_notification'
```

### Rails

In order to install ExceptionNotification as an [engine](https://api.rubyonrails.org/classes/Rails/Engine.html), just run the following command from the terminal:

    rails g exception_notification:install

This generates an initializer file, `config/initializers/exception_notification.rb` with some default configuration, which you should modify as needed.

Make sure the gem is not listed solely under the `production` group in your `Gemfile`, since this initializer will be loaded regardless of environment. If you want it to only be enabled in production, you can add this to your configuration:

```ruby
  config.ignore_if do |exception, options|
    not Rails.env.production?
  end
```

The generated initializer file will include this require:
```ruby
require 'exception_notification/rails'
```

which automatically adds the ExceptionNotification middleware to the Rails middleware stack. This middleware is what watches for unhandled exceptions from your Rails app (except for [background jobs](#background-jobs)) and notifies you when they occur.

The generated file adds an `email` notifier:

```ruby
  config.add_notifier :email, {
    email_prefix: '[ERROR] ',
    sender_address: %{"Notifier" <notifier@example.com>},
    exception_recipients: %w{exceptions@example.com}
  }
```

**Note**: In order to enable delivery notifications by email, make sure you have [ActionMailer configured](docs/notifiers/email.md#actionmailer-configuration).

#### Adding middleware manually

Alternatively, if for some reason you don't want to `require 'exception_notification/rails'`, you can manually add the middleware, like this:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  email: {
    email_prefix: '[PREFIX] ',
    sender_address: %{"notifier" <notifier@example.com>},
    exception_recipients: %w{exceptions@example.com}
  }
```

This is the older way of configuring ExceptionNotification (which prior to version 4 was the _only_ way to configure it), and is still the way used in some of the examples.

Options passed to the `ExceptionNotification::Rack` middleware in this way are translated to the equivalent configuration options for the `ExceptionNotification.configure` of configuring (compare to the [Rails](#rails) example above).


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

ExceptionNotification relies on notifiers to deliver notifications when errors occur in your applications. By default, 8 notifiers are available:

* [Datadog notifier](docs/notifiers/datadog.md)
* [Email notifier](docs/notifiers/email.md)
* [HipChat notifier](docs/notifiers/hipchat.md)
* [IRC notifier](docs/notifiers/irc.md)
* [Slack notifier](docs/notifiers/slack.md)
* [Mattermost notifier](docs/notifiers/mattermost.md)
* [Teams notifier](docs/notifiers/teams.md)
* [Amazon SNS](docs/notifiers/sns.md)
* [Google Chat notifier](docs/notifiers/google_chat.md)
* [WebHook notifier](docs/notifiers/webhook.md)

But, you also can easily implement your own [custom notifier](docs/notifiers/custom.md).

## Error Grouping

In general, ExceptionNotification will send a notification when every error occurs, which may result in a problem: if your site has a high throughput and a particular error is raised frequently, you will receive too many notifications. During a short period of time, your mail box may be filled with thousands of exception mails, or your mail server may even become slow. To prevent this, you can choose to group errors by setting the `:error_grouping` option to `true`.

Error grouping uses a default formula of `Math.log2(errors_count)` to determine whether to send the notification, based on the accumulated error count for each specific exception. This makes the notifier only send a notification when the count is: 1, 2, 4, 8, 16, 32, 64, 128, ..., (2**n). You can use `:notification_trigger` to override this default formula.

The following code shows the available options to configure error grouping:

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

* `:ignore_notifer_if` - Custom (i.e. let each notifier ignore exceptions if by-notifier condition is satisfied)


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

You can ignore exceptions based on a condition. Take a look:

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

### :ignore_notifier_if

* Hash of Lambda, default: nil*

In case you want a notifier to ignore certain exceptions, but don't want other notifiers to skip them, you can set by-notifier ignore options.
By setting below, each notifier will ignore exceptions when its corresponding condition is met.

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        ignore_notifier_if: {
                                          email: ->(env, exception) { !Rails.env.production? },
                                          slack: ->(env, exception) { exception.message =~ /^Couldn't find Page with ID=/ }
                                        },

                                        email: {
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com}
                                        },
                                        slack: {
                                          webhook_url: '[Your webhook url]',
                                          channel: '#exceptions',
                                        }
```

To customize each condition, you can make use of environment and the exception object inside the lambda.

## Rack X-Cascade Header

Some rack apps (Rails in particular) utilize the "X-Cascade" header to pass the request-handling responsibility to the next middleware in the stack.

Rails' routing middleware uses this strategy, rather than raising an exception, to handle routing errors (e.g. 404s); to be notified whenever a 404 occurs, set this option to "false."

### :ignore_cascade_pass

*Boolean, default: true*

Set to false to trigger notifications when another rack middleware sets the "X-Cascade" header to "pass."

## Background Jobs

The ExceptionNotification middleware can only detect notifications that occur during web requests (controller actions). If you have any Ruby code that gets run _outside_ of a normal web request (hereafter referred to as a "background job" or "background process"), exceptions must be detected a different way (the middleware won't even be running in this context).

Examples of background jobs include jobs triggered from a cron file or from a queue.

ExceptionNotificatior can be configured to automatically notify of exceptions occurring in most common types of Rails background jobs such as [rake tasks](#rake-tasks). Additionally, it provides optional integrations for some 3rd-party libraries such as [Resque and Sidekiq](#resquesidekiq). And of course you can manually trigger a notification if no integration is provided.

### Rails runner

To enable exception notification for your runner commands, add this line to your `config/application.rb` _below_ the `Bundler.require` line (ensuring that `exception_notification` and `rails` gems will have already been required):

```ruby
require 'exception_notification/rails'
```

(Requiring it from an initializer is too late, because this depends on the `runner` callback, and that will have already been fired _before_ any initializers run.)

### Rake tasks

If you've already added `require 'exception_notification/rails'` to your `config/application.rb` as described [above](#rails-runner), then there's nothing further you need to do. (That Engine has a `rake_tasks` callback which automatically requires the file below.)

Alternatively, you can add this line to your `config/initializers/exception_notification.rb`:

```ruby
require 'exception_notification/rake'
```

### Manually notify of exceptions

If you want to manually send a notifications from a background process that is not _automatically_ handled by ExceptionNotification, then you need to manually call the `notify_exception` method like this:

```ruby
begin
  # some code...
rescue => e
  ExceptionNotifier.notify_exception(e)
end
```

You can include information about the background process that created the error by including a `data` parameter:

```ruby
begin
  # some code...
rescue => e
  ExceptionNotifier.notify_exception(
    e,
    data: { worker: worker.to_s, queue: queue, payload: payload}
  )
end
```

### Resque/Sidekiq

Instead of manually calling background notifications for each job/worker, you can configure ExceptionNotification to do this automatically. For this, run:

    rails g exception_notification:install --resque

or

    rails g exception_notification:install --sidekiq

As above, make sure the gem is not listed solely under the `production` group, since this initializer will be loaded regardless of environment.

## Manually notify of exceptions from `rescue_from` handler

If your controller rescues and handles an error, the middleware won't be able to see that there was an exception, and the notifier will never be run. To manually notify of an error after rescuing it, you can do something like the following:

```ruby
class SomeController < ApplicationController
  rescue_from Exception, with: :server_error

  def server_error(exception)
    # Whatever code that handles the exception

    ExceptionNotifier.notify_exception(
      exception,
      env: request.env, data: { message: 'was doing something wrong' }
    )
  end
end
```

## Support and tickets

Here's the list of [issues](https://github.com/smartinez87/exception_notification/issues) we're currently working on.

To contribute, please read first the [Contributing Guide](https://github.com/smartinez87/exception_notification/blob/master/CONTRIBUTING.md).

## Code of Conduct

Everyone interacting in this project's codebases, issue trackers, chat rooms, and mailing lists is expected to follow our [code of conduct](https://github.com/smartinez87/exception_notification/blob/master/CODE_OF_CONDUCT.md).

## License

Copyright (c) 2005 Jamis Buck, released under the [MIT license](http://www.opensource.org/licenses/MIT).
