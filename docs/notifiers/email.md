### Email notifier

The Email notifier sends notifications by email. The notifications/emails sent includes information about the current request, session, and environment, and also gives a backtrace of the exception.

After an exception notification has been delivered the rack environment variable `exception_notifier.delivered` will be set to true.

#### ActionMailer configuration

For the email to be sent, there must be a default ActionMailer `delivery_method` setting configured. If you do not have one, you can use the following code (assuming your app server machine has `sendmail`). Depending on the environment you want ExceptionNotification to run in, put the following code in your `config/environments/production.rb` and/or `config/environments/development.rb`:

```ruby
config.action_mailer.delivery_method = :sendmail
# Defaults to:
# config.action_mailer.sendmail_settings = {
#   location: '/usr/sbin/sendmail',
#   arguments: '-i -t'
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
                                        email: {
                                          email_prefix: '[PREFIX] ',
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com},
                                          sections: %w{my_section1 my_section2}
                                        }
```

Place your custom sections under `./app/views/exception_notifier/` with the suffix `.text.erb`, e.g. `./app/views/exception_notifier/_my_section1.text.erb`.

If your new section requires information that isn't available by default, make sure it is made available to the email using the `exception_data` macro:

```ruby
class ApplicationController < ActionController::Base
  before_action :log_additional_data
  ...
  protected

  def log_additional_data
    request.env['exception_notifier.exception_data'] = {
      document: @document,
      person: @person
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
                                        email: {
                                          email_prefix: '[PREFIX] ',
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com},
                                          background_sections: %w{my_section1 my_section2 backtrace data}
                                        }
```

##### email_headers

*Hash of strings, default: {}*

Additionally, you may want to set customized headers on the outcoming emails. To do so, simply use the `:email_headers` option:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        email: {
                                          email_prefix: "[PREFIX] ",
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com},
                                          email_headers: { "X-Custom-Header" => "foobar" }
                                        }
```

##### verbose_subject

*Boolean, default: true*

If enabled, include the exception message in the subject. Use `verbose_subject: false` to exclude it.

##### normalize_subject

*Boolean, default: false*

If enabled, remove numbers from subject so they thread as a single one. Use `normalize_subject: true` to enable it.

##### include_controller_and_action_names_in_subject

*Boolean, default: true*

If enabled, include the controller and action names in the subject. Use `include_controller_and_action_names_in_subject: false` to exclude them.

##### email_format

*Symbol, default: :text*

By default, ExceptionNotification sends emails in plain text, in order to sends multipart notifications (aka HTML emails) use `email_format: :html`.

##### delivery_method

*Symbol, default: :smtp*

By default, ExceptionNotification sends emails using the ActionMailer configuration of the application. In order to send emails by another delivery method, use the `delivery_method` option:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        email: {
                                          email_prefix: '[PREFIX] ',
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com},
                                          delivery_method: :postmark,
                                          postmark_settings: {
                                            api_key: ENV['POSTMARK_API_KEY']
                                          }
                                        }
```

Besides the `delivery_method` option, you also can customize the mailer settings by passing a hash under an option named `DELIVERY_METHOD_settings`. Thus, you can use override specific SMTP settings for notifications using:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        email: {
                                          email_prefix: '[PREFIX] ',
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com},
                                          delivery_method: :smtp,
                                          smtp_settings: {
                                            user_name: 'bob',
                                            password: 'password',
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
