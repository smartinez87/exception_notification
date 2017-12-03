# Exception Notification

[![Gem Version](https://fury-badge.herokuapp.com/rb/exception_notification.png)](http://badge.fury.io/rb/exception_notification)
[![Travis](https://api.travis-ci.org/smartinez87/exception_notification.png)](http://travis-ci.org/smartinez87/exception_notification)
[![Coverage Status](https://coveralls.io/repos/smartinez87/exception_notification/badge.png?branch=master)](https://coveralls.io/r/smartinez87/exception_notification)
[![Code Climate](https://codeclimate.com/github/smartinez87/exception_notification.png)](https://codeclimate.com/github/smartinez87/exception_notification)

**THIS README IS FOR THE MASTER BRANCH AND REFLECTS THE WORK CURRENTLY EXISTING ON THE MASTER BRANCH. IF YOU ARE WISHING TO USE A NON-MASTER BRANCH OF EXCEPTION NOTIFICATION, PLEASE CONSULT THAT BRANCH'S README AND NOT THIS ONE.**

---

The Exception Notification gem provides a set of [notifiers](#notifiers) for sending notifications when errors occur in a Rack/Rails application. The built-in notifiers can deliver notifications by [email](#email-notifier), [Campfire](#campfire-notifier), [HipChat](#hipchat-notifier), [Slack](#slack-notifier), [Mattermost](#mattermost-notifier), [IRC](#irc-notifier) or via custom [WebHooks](#webhook-notifier).

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
  :email => {
    :deliver_with => :deliver, # Rails >= 4.2.1 do not need this option since it defaults to :deliver_now
    :email_prefix => "[PREFIX] ",
    :sender_address => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com}
  }
```

**Note**: In order to enable delivery notifications by email make sure you have [ActionMailer configured](#actionmailer-configuration).

### Rack/Sinatra

In order to use ExceptionNotification with Sinatra, please take a look in the [example application](https://github.com/smartinez87/exception_notification/tree/master/examples/sinatra).

### Custom Data, e.g. Current User

Save the current user in the `request` using a controller callback.

```ruby
class ApplicationController < ActionController::Base
  before_filter :prepare_exception_notifier
  private
  def prepare_exception_notifier
    request.env["exception_notifier.exception_data"] = {
      :current_user => current_user
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

ExceptionNotification relies on notifiers to deliver notifications when errors occur in your applications. By default, 7 notifiers are available:

* [Campfire notifier](#campfire-notifier)
* [Email notifier](#email-notifier)
* [HipChat notifier](#hipchat-notifier)
* [IRC notifier](#irc-notifier)
* [Slack notifier](#slack-notifier)
* [Mattermost notifier](#mattermost-notifier)
* [WebHook notifier](#webhook-notifier)

But, you also can easily implement your own [custom notifier](#custom-notifier).

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
  :email => {
    :email_prefix => "[PREFIX] ",
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

### Email notifier

The Email notifier sends notifications by email. The notifications/emails sent includes information about the current request, session, and environment, and also gives a backtrace of the exception.

After an exception notification has been delivered the rack environment variable `exception_notifier.delivered` will be set to true.

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

*String/Array of strings/Proc, default: []*

Who the message is destined for, can be a string of addresses, an array of addresses, or it can be a proc that returns a string of addresses or an array of addresses. The proc will be evaluated when the mail is sent.

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
Rails.application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix => "[PREFIX] ",
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
Rails.application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix => "[PREFIX] ",
    :sender_address => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com},
    :background_sections => %w{my_section1 my_section2 backtrace data}
  }
```

##### email_headers

*Hash of strings, default: {}*

Additionally, you may want to set customized headers on the outcoming emails. To do so, simply use the `:email_headers` option:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix         => "[PREFIX] ",
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

##### include_controller_and_action_names_in_subject

*Boolean, default: true*

If enabled, include the controller and action names in the subject. Use `:include_controller_and_action_names_in_subject => false` to exclude them.

##### email_format

*Symbol, default: :text*

By default, ExceptionNotification sends emails in plain text, in order to sends multipart notifications (aka HTML emails) use `:email_format => :html`.

##### delivery_method

*Symbol, default: :smtp*

By default, ExceptionNotification sends emails using the ActionMailer configuration of the application. In order to send emails by another delivery method, use the `delivery_method` option:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix         => "[PREFIX] ",
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
Rails.application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix         => "[PREFIX] ",
    :sender_address       => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com},
    :delivery_method => :smtp,
    :smtp_settings => {
      :user_name => "bob",
      :password => "password",
    }
  }
```

A complete list of `smtp_settings` options can be found in the [ActionMailer Configuration documentation](http://api.rubyonrails.org/classes/ActionMailer/Base.html#class-ActionMailer::Base-label-Configuration+options).

##### mailer_parent

*String, default: ActionMailer::Base*

The parent mailer which ExceptionNotification mailer inherit from.

##### deliver_with

*Symbol, default: :deliver_now

The method name to send emalis using ActionMailer.

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
  :email => {
    :email_prefix => "[PREFIX] ",
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

### IRC notifier

This notifier sends notifications to an IRC channel using the carrier-pigeon gem.

#### Usage

Just add the [carrier-pigeon](https://github.com/portertech/carrier-pigeon) gem to your `Gemfile`:

```ruby
gem 'carrier-pigeon'
```

To configure it, you need to set at least the 'domain' option, like this:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix => "[PREFIX] ",
    :sender_address => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com}
  },
  :irc => {
    :domain => 'irc.example.com'
  }
```

There are several other options, which are described below. For example, to use ssl and a password, add a prefix, post to the '#log' channel, and include recipients in the message (so that they will be notified), your configuration might look like this:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  :irc => {
    :domain => 'irc.example.com',
    :nick => 'BadNewsBot',
    :password => 'secret',
    :port => 6697,
    :channel => '#log',
    :ssl => true,
    :prefix => '[Exception Notification]',
    :recipients => ['peter', 'michael', 'samir']
  }

```

#### Options

##### domain

*String, required*

The domain name of your IRC server.

##### nick

*String, optional*

The message will appear from this nick. Default : 'ExceptionNotifierBot'.

##### password

*String, optional*

Password for your IRC server.

##### port

*String, optional*

Port your IRC server is listening on. Default : 6667.

##### channel

*String, optional*

Message will appear in this channel. Default : '#log'.

##### notice

*Boolean, optional*

Send a notice. Default : false.

##### ssl

*Boolean, optional*

Whether to use SSL. Default : false.

##### join

*Boolean, optional*

Join a channel. Default : false.

##### recipients

*Array of strings, optional*

Nicks to include in the message. Default: []

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
  :email => {
    :email_prefix => "[PREFIX] ",
    :sender_address => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com}
  },
  :slack => {
    :webhook_url => "[Your webhook url]",
    :channel => "#exceptions",
    :additional_parameters => {
      :icon_url => "http://image.jpg",
      :mrkdwn => true
    }
  }
```

The slack notification will include any data saved under `env["exception_notifier.exception_data"]`.

An example of how to send the server name to Slack in Rails (put this code in application_controller.rb):

```ruby
before_filter :set_notification

def set_notification
     request.env['exception_notifier.exception_data'] = {"server" => request.env['SERVER_NAME']}
     # can be any key-value pairs
end
```

If you find this too verbose, you can determine to exclude certain information by doing the following:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  :slack => {
    :webhook_url => "[Your webhook url]",
    :channel => "#exceptions",
    :additional_parameters => {
      :icon_url => "http://image.jpg",
      :mrkdwn => true
    },
    :ignore_data_if => lambda {|key, value|
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

## Mattermost notifier

Post notification in a mattermost channel via [incoming webhook](http://docs.mattermost.com/developer/webhooks-incoming.html)

Just add the [HTTParty](https://github.com/jnunemaker/httparty) gem to your `Gemfile`:

```ruby
gem 'httparty'
```

To configure it, you **need** to set the `webhook_url` option.
You can also specify an other channel with `channel` option.

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix => "[PREFIX] ",
    :sender_address => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com}
  },
  :mattermost => {
    :webhook_url => 'http://your-mattermost.com/hooks/blablabla',
    :channel => 'my-channel'
  }
```

If you are using Github or Gitlab for issues tracking, you can specify `git_url` as follow to add a *Create issue* link in you notification.
By default this will use your Rails application name to match the git repository. If yours differ you can specify `app_name`.


```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix => "[PREFIX] ",
    :sender_address => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com}
  },
  :mattermost => {
    :webhook_url => 'http://your-mattermost.com/hooks/blablabla',
    :git_url => 'github.com/aschen'
  }
```

You can also specify the bot name and avatar with `username` and `avatar` options.

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix => "[PREFIX] ",
    :sender_address => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com}
  },
  :mattermost => {
    :webhook_url => 'http://your-mattermost.com/hooks/blablabla',
    :avatar => 'http://example.com/your-image.png',
    :username => 'Fail bot'
  }
```

Finally since the notifier use HTTParty, you can include all HTTParty options, like basic_auth for example.

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix => "[PREFIX] ",
    :sender_address => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com}
  },
  :mattermost => {
    :webhook_url => 'http://your-mattermost.com/hooks/blablabla',
    :basic_auth => {
      :username => 'clara',
      :password => 'password'
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

Your application name used for issue creation link. Defaults to ``` Rails.application.class.parent_name.underscore```.


### WebHook notifier

This notifier ships notifications over the HTTP protocol.

#### Usage

Just add the [HTTParty](https://github.com/jnunemaker/httparty) gem to your `Gemfile`:

```ruby
gem 'httparty'
```

To configure it, you need to set the `url` option, like this:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix => "[PREFIX] ",
    :sender_address => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com}
  },
  :webhook => {
    :url => 'http://domain.com:5555/hubot/path'
  }
```

By default, the WebhookNotifier will call the URLs using the POST method. But, you can change this using the `http_method` option.

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix => "[PREFIX] ",
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
Rails.application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix => "[PREFIX] ",
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
Rails.application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix => "[PREFIX] ",
    :sender_address => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com}
  },
  :simple => {
    # simple notifier options
  }
```

## Error Grouping
In general, exception notification will send every notification when an error occured, which may result in a problem: if your site has a high throughput and an same error raised frequently, you will receive too many notifications during a short period time, your mail box may be full of thousands of exception mails or even your mail server will be slow. To prevent this, you can choose to error errors by using `:error_grouping` option and set it to `true`.

Error grouping has a default formula `log2(errors_count)` to determine if it is needed to send the notification based on the accumulated errors count for specified exception, this makes the notifier only send notification when count is: 1, 2, 4, 8, 16, 32, 64, 128, ... (2**n). You can use `:notification_trigger` to override this default formula.

The below shows options used to enable error grouping:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  :ignore_exceptions => ['ActionView::TemplateError'] + ExceptionNotifier.ignored_exceptions,
  :email => {
    :email_prefix         => "[PREFIX] ",
    :sender_address       => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com}
  },
  :error_grouping => true,
  # :error_grouping_period => 5.minutes,    # the time before an error is regarded as fixed
  # :error_grouping_cache => Rails.cache,   # for other applications such as Sinatra, use one instance of ActiveSupport::Cache::Store
  #
  # notification_trigger: specify a callback to determine when a notification should be sent,
  #   the callback will be invoked with two arguments:
  #     exception: the exception raised
  #     count: accumulated errors count for this exception
  #
  # :notification_trigger => lambda { |exception, count| count % 10 == 0 }
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
  :ignore_exceptions => ['ActionView::TemplateError'] + ExceptionNotifier.ignored_exceptions,
  :email => {
    :email_prefix         => "[PREFIX] ",
    :sender_address       => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com}
  }
```

The above will make ExceptionNotifier ignore a *TemplateError* exception, plus the ones ignored by default.

### :ignore_crawlers

*Array of strings, default: []*

In some cases you may want to avoid getting notifications from exceptions made by crawlers. To prevent sending those unwanted notifications, use the `:ignore_crawlers` option like this:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  :ignore_crawlers => %w{Googlebot bingbot},
  :email => {
    :email_prefix         => "[PREFIX] ",
    :sender_address       => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com}
  }
```

### :ignore_if

*Lambda, default: nil*

Last but not least, you can ignore exceptions based on a condition. Take a look:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  :ignore_if => ->(env, exception) { exception.message =~ /^Couldn't find Page with ID=/ },
  :email => {
    :email_prefix         => "[PREFIX] ",
    :sender_address       => %{"notifier" <notifier@example.com>},
    :exception_recipients => %w{exceptions@example.com},
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
