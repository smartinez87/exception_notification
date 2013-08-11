# Exception Notification

[![Gem Version](https://fury-badge.herokuapp.com/rb/exception_notification.png)](http://badge.fury.io/rb/exception_notification)
[![Travis](https://api.travis-ci.org/smartinez87/exception_notification.png)](http://travis-ci.org/smartinez87/exception_notification)
[![Coverage Status](https://coveralls.io/repos/smartinez87/exception_notification/badge.png?branch=master)](https://coveralls.io/r/smartinez87/exception_notification)
[![Code Climate](https://codeclimate.com/github/smartinez87/exception_notification.png)](https://codeclimate.com/github/smartinez87/exception_notification)
![project status](http://stillmaintained.com/smartinez87/exception_notification.png)

**THIS README IS FOR THE MASTER BRANCH AND REFLECTS THE WORK CURRENTLY EXISTING ON THE MASTER BRANCH. IF YOU ARE WISHING TO USE A NON-MASTER BRANCH OF EXCEPTION NOTIFICATION, PLEASE CONSULT THAT BRANCH'S README AND NOT THIS ONE.**

-

The Exception Notification gem provides a set of [notifiers](#notifiers) for sending notifications when errors occur in a Rack/Rails application.

The built-in notifiers can deliver notifications by [email](#email-notifier), [campfire rooms](#campfire-notifier) or via [webhooks](#webhook-notifier).


There's a great [Railscast about Exception Notification](http://railscasts.com/episodes/104-exception-notifications-revised) you can see that may help you getting started.

[Follow us on Twitter](https://twitter.com/exception_notif) to get updates and notices about new releases.


## Requirements

* Ruby 1.9.3 or greater
* Rails 3.1 or greater, Sinatra or another Rack-based application.

For previous releases, please checkout [this](#versions).


## Getting Started

Add the following line to your application's Gemfile:

```ruby
gem 'exception_notification'
```

As of Rails 3 ExceptionNotification is used as a rack middleware, or in the environment you want it to run. In most cases you would want ExceptionNotification to run on production. Thus, you can make it work by putting the following lines in your `config/environments/production.rb`:

```ruby
Whatever::Application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix => "[Whatever] ",
    :sender_address => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com}
  }
```

> **Note**: In order to enable delivery notifications by email make sure you have [ActionMailer configured](#actionmailer-configuration).


In order to use ExceptionNotification with Sinatra, please take a look in the [example application](https://github.com/smartinez87/exception_notification/tree/master/examples/sinatra).


### Upgrading to 4.x version

As of 4.x version the configuration syntax has changed. All email related options MUST BE nested under the `:email` key. Thus, previous configuration like:

```ruby
Whatever::Application.config.middleware.use ExceptionNotifier,
  :email_prefix => "[Whatever] ",
  :sender_address => %{"notifier" <notifier@example.com>},
  :exception_recipients => %w{exceptions@example.com}
```

becomes:

```ruby
Whatever::Application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix => "[Whatever] ",
    :sender_address => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com}
  }
```

Beside that, the rack middleware was renamed to `ExceptionNotification::Rack`.

## Notifiers

ExceptionNotification relies on notifiers to deliver notifications when errors occur in your applications. By default, three notifiers are available: [email notifier](#email-notifier), [campfire notifier](#campfire-notifier) and [webhook notifier](#webhook-notifier). But, you also can easily implement your own [custom notifier](#custom-notifier).


### Email notifier

The Email notifier sends notifications by email. The notifications/emails sent includes information about the current request, session, and environment, and also gives a backtrace of the exception.

After an exception notification has been delivered the rack environment variable 'exception_notifier.delivered' will be set to true.

#### ActionMailer configuration

For the email to be sent, there must be a default ActionMailer `delivery_method` setting configured. If you do not have one, you can use the following code (assuming your app server machine has `sendmail`). Depending on the environment you want ExceptionNotification to run in, put the following code in your `config/environments/production.rb` and/or `config/environments/development.rb`:

```ruby
config.action_mailer.delivery_method = :sendmail
# Defaults to:
# config.action_mailer.sendmail_settings = {
#   :location => '/usr/sbin/sendmail',
#   :arguments => '-i -t'
# }
config.action_mailer.perform_deliveries = true
config.action_mailer.raise_delivery_errors = true
```

#### Options

##### sender_address

*String, default: %("Exception Notifier" <exception.notifier@example.com>)*

Who the message is from.


##### exception_recipients

*String/Array of strings, default: []*

Who the message is destined for, can be a string of addresses, or an array of addresses.


##### email_prefix

*String, default: [ERROR]*

The subject's prefix of the message.


##### sections

*Array of strings, default: %w(request session environment backtrace)*

By default, the notification email includes four parts: request, session, environment, and backtrace (in that order). You can customize how each of those sections are rendered by placing a partial named for that part in your `app/views/exception_notifier` directory (e.g., `_session.rhtml`). Each partial has access to the following variables:

```ruby
@kontroller     # the controller that caused the error
@request        # the current request object
@exception      # the exception that was raised
@backtrace      # a sanitized version of the exception's backtrace
@data           # a hash of optional data values that were passed to the notifier
@sections       # the array of sections to include in the email
```

You can reorder the sections, or exclude sections completely, by using `sections` option. You can even add new sections that
describe application-specific data--just add the section's name to the list (wherever you'd like), and define the corresponding partial. Like the following example with two new added sections:

```ruby
Whatever::Application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix => "[Whatever] ",
    :sender_address => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com},
    :sections => %w{my_section1 my_section2}
  }
```

Place your custom sections under `./app/views/exception_notifier/` with the suffix `.text.erb`, e.g. `./app/views/exception_notifier/_my_section1.text.erb`.

If your new section requires information that isn't available by default, make sure it is made available to the email using the `exception_data` macro:

```ruby
class ApplicationController < ActionController::Base
  before_filter :log_additional_data
  ...
  protected
    def log_additional_data
      request.env["exception_notifier.exception_data"] = {
        :document => @document,
        :person => @person
      }
    end
  ...
end
```

In the above case, `@document` and `@person` would be made available to the email renderer, allowing your new section(s) to access and display them. See the existing sections defined by the plugin for examples of how to write your own.


##### background_sections

*Array of strings, default: %w(backtrace data)*

When using [background notifications](#background-notifications) some variables are not available in the views, like `@kontroller` and `@request`. Thus, you may want to include different sections for background notifications:

```ruby
Whatever::Application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix => "[Whatever] ",
    :sender_address => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com},
    :background_sections => %w{my_section1 my_section2 backtrace data}
  }
```


##### email_headers

*Hash of strings, default: {}*

Additionally, you may want to set customized headers on the outcoming emails. To do so, simply use the `:email_headers` option:

```ruby
Whatever::Application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix         => "[Whatever] ",
    :sender_address       => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com},
    :email_headers        => { "X-Custom-Header" => "foobar" }
  }
```


##### verbose_subject

*Boolean, default: true*

If enabled, include the exception message in the subject. Use `:verbose_subject => false` to exclude it.


##### normalize_subject

*Boolean, default: false*

If enabled, remove numbers from subject so they thread as a single one. Use `:normalize_subject => true` to enable it.


##### email_format

*Symbol, default: :text*

By default, ExceptionNotification sends emails in plain text, in order to sends multipart notifications (aka HTML emails) use `:email_format => :html`.


##### delivery_method

*Symbol, default: :smtp*

By default, ExceptionNotification sends emails using the ActionMailer configuration of the application. In order to send emails by another delivery method, use the `delivery_method` option:

```ruby
Whatever::Application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix         => "[Whatever] ",
    :sender_address       => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com},
    :delivery_method => :postmark,
    :postmark_settings => {
      :api_key => ENV["POSTMARK_API_KEY"]
    }
  }
```

Besides the `delivery_method` option, you also can customize the mailer settings by passing a hash under an option named `DELIVERY_METHOD_settings`. Thus, you can use override specific SMTP settings for notifications using:

```ruby
Whatever::Application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix         => "[Whatever] ",
    :sender_address       => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com},
    :delivery_method => :smtp,
    :smtp_settings => {
      :user_name => "bob",
      :password => "password",
    }
  }
```


##### mailer_parent

*String, default: ActionMailer::Base*

The parent mailer which ExceptionNotification mailer inherit from.


### Campfire notifier

This notifier sends notifications to your Campfire room.

#### Usage

Just add the [tinder](https://github.com/collectiveidea/tinder) gem to your `Gemfile`:

```ruby
gem 'tinder'
```

To configure it, you need to set the `subdomain`, `token` and `room_name` options, like this:

```ruby
Whatever::Application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix => "[Whatever] ",
    :sender_address => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com}
  },
  :campfire => {
    :subdomain => 'my_subdomain',
    :token => 'my_token',
    :room_name => 'my_room'
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


### HipChat notifier

This notifier sends notifications to your Hipchat room.

#### Usage

Just add the [hipchat](https://github.com/hipchat/hipchat) gem to your `Gemfile`:

```ruby
gem 'hipchat'
```

To configure it, you need to set the `token` and `room_name` options, like this:

```ruby
Whatever::Application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix => "[Whatever] ",
    :sender_address => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com}
  },
  :hipchat => {
    :api_token => 'my_token',
    :room_name => 'my_room'
  }
```

#### Options

##### room_name

*String, required*

The HipChat room where the notifications must be published to.

##### api_token

*String, required*

The API token to allow access to your HipChat account.

##### announce

*Boolean, optionnal*

Notify users. Default : false.

##### color

*String, optionnal*

Color of the message. Default : 'red'.

##### from

*String, optionnal*

Message will appear from this nickname. Default : 'Exception'.

For all options & possible values see [Hipchat API](https://www.hipchat.com/docs/api/method/rooms/message).

### Webhook notifier

This notifier ships notifications over the HTTP protocol.

#### Usage

Just add the [HTTParty](https://github.com/jnunemaker/httparty) gem to your `Gemfile`:

```ruby
gem 'httparty'
```

To configure it, you need to set the `url` option, like this:

```ruby
Whatever::Application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix => "[Whatever] ",
    :sender_address => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com}
  },
  :webhook => {
    :url => 'http://domain.com:5555/hubot/path'
  }
```

By default, the WebhookNotifier will call the URLs using the POST method. But, you can change this using the `http_method` option.

```ruby
Whatever::Application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix => "[Whatever] ",
    :sender_address => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com}
  },
  :webhook => {
    :url => 'http://domain.com:5555/hubot/path',
    :http_method => :get
  }
```

Besides the `url` and `http_method` options, all the other options are passed directly to HTTParty. Thus, if the HTTP server requires authentication, you can include the following options:

```ruby
Whatever::Application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix => "[Whatever] ",
    :sender_address => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com}
  },
  :webhook => {
    :url => 'http://domain.com:5555/hubot/path',
    :basic_auth => {
      :username => 'alice',
      :password => 'password'
    }
  }
```

For more HTTParty options, check out the [documentation](https://github.com/jnunemaker/httparty).


### Custom notifier

Simply put, notifiers are objects which respond to `#call(exception, options)` method. Thus, a lambda can be used as a notifier as follow:

```ruby
ExceptionNotifier.add_notifier :custom_notifier_name,
  ->(exception, options) { puts "Something goes wrong: #{exception.message}"}
```

More advanced users or third-party framework developers, also can create notifiers to be shipped in gems and take advantage of ExceptionNotification's Notifier API to standardize the [various](https://github.com/airbrake/airbrake) [solutions](https://www.honeybadger.io) [out](http://www.exceptional.io) [there](https://bugsnag.com). For this, beyond the `#call(exception, options)` method, the notifier class MUST BE defined under the ExceptionNotifier namespace and its name sufixed by `Notifier`, e.g: ExceptionNotifier::SimpleNotifier.

#### Example

Define the custom notifier:

```ruby
module ExceptionNotifier
  class SimpleNotifier
    def initialize(options)
      # do something with the options...
    end

    def call(exception, options={})
      # send the notification
    end
  end
end
```

Using it:

```ruby
Whatever::Application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix => "[Whatever] ",
    :sender_address => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com}
  },
  :simple => {
    # simple notifier options
  }
```


## Ignore Exceptions

You can choose to ignore certain exceptions, which will make ExceptionNotification avoid sending notifications for those specified. There are three ways of specifying which exceptions to ignore:

* `:ignore_exceptions` - By exception class (i.e. ignore RecordNotFound ones)

* `:ignore_crawlers`   - From crawler (i.e. ignore ones originated by Googlebot)

* `:ignore_if`         - Custom (i.e. ignore exceptions that satisfy some condition)


### :ignore_exceptions

*Array of strings, default: %w{ActiveRecord::RecordNotFound AbstractController::ActionNotFound ActionController::RoutingError}*

Ignore specified exception types. To achieve that, you should use the `:ignore_exceptions` option, like this:

```ruby
Whatever::Application.config.middleware.use ExceptionNotification::Rack,
  :ignore_exceptions => ['ActionView::TemplateError'] + ExceptionNotifier.ignored_exceptions,
  :email => {
    :email_prefix         => "[Whatever] ",
    :sender_address       => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com}
  }
```

The above will make ExceptionNotifier ignore a *TemplateError* exception, plus the ones ignored by default.

### :ignore_crawlers

*Array of strings, default: []*

In some cases you may want to avoid getting notifications from exceptions made by crawlers. To prevent sending those unwanted notifications, use the `:ignore_crawlers` option like this:

```ruby
Whatever::Application.config.middleware.use ExceptionNotification::Rack,
  :ignore_crawlers => %w{Googlebot bingbot},
  :email => {
    :email_prefix         => "[Whatever] ",
    :sender_address       => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com}
  }
```

### :ignore_if

*Lambda, default: nil*

Last but not least, you can ignore exceptions based on a condition. Take a look:

```ruby
Whatever::Application.config.middleware.use ExceptionNotification::Rack,
  :ignore_if => ->(env, exception) { exception.message =~ /^Couldn't find Page with ID=/ },
  :email => {
    :email_prefix         => "[Whatever] ",
    :sender_address       => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com},
  }
```

You can make use of both the environment and the exception inside the lambda to decide wether to avoid or not sending the notification.


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
rescue => exception
  ExceptionNotifier.notify_exception(exception,
    :data => {:worker => worker.to_s, :queue => queue, :payload => payload})
end
```

### Manually notify of exception

If your controller action manually handles an error, the notifier will never be run. To manually notify of an error you can do something like the following:

```ruby
rescue_from Exception, :with => :server_error

def server_error(exception)
  # Whatever code that handles the exception

  ExceptionNotifier.notify_exception(exception,
    :env => request.env, :data => {:message => "was doing something wrong"})
end
```


## Extras

### Rails

Since his first version, ExceptionNotification was just a simple rack middleware. But, the version 4.0.0 introduced the option to use it as a Rails engine. In order to use ExceptionNotification as an engine, just run the following command from the terminal:

    rails g exception_notification:install

This command generates an initialize file (`config/initializers/exception_notification.rb`) where you can customize your configurations.


### Resque/Sidekiq

Instead of manually calling background notifications foreach job/worker, you can configure ExceptionNotification to do this automatically. For this, run:

    rails g exception_notification:install --resque

or

    rails g exception_notification:install --sidekiq


## Versions

For v4.0.0, see this tag:

http://github.com/smartinez87/exception_notification/tree/v4.0.0

For v3.0.1, see this tag:

http://github.com/smartinez87/exception_notification/tree/v3.0.1

For v3.0.0, see this tag:

http://github.com/smartinez87/exception_notification/tree/v3.0.0

For v2.6.1, see this tag:

http://github.com/smartinez87/exception_notification/tree/v2.6.1

For previous releases, visit:

https://github.com/smartinez87/exception_notification/tags

If you are running Rails 2.3 then see the branch for that:

http://github.com/smartinez87/exception_notification/tree/2-3-stable

If you are running pre-rack Rails then see this tag:

http://github.com/smartinez87/exception_notification/tree/pre-2-3


## Support and tickets

Here's the list of [issues](https://github.com/smartinez87/exception_notification/issues) we're currently working on.

To contribute, please read first the [Contributing Guide](https://github.com/smartinez87/exception_notification/blob/master/CONTRIBUTING.md).


## License

Copyright (c) 2005 Jamis Buck, released under the [MIT license](http://www.opensource.org/licenses/MIT).
