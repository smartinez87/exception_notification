Exception Notifier Plugin for Rails [![Travis](http://travis-ci.org/smartinez87/exception_notification.png)](http://travis-ci.org/smartinez87/exception_notification)
====

The Exception Notifier plugin provides a mailer object and a default set of
templates for sending email notifications when errors occur in a Rails
application. The plugin is configurable, allowing programmers to specify:

* the sender address of the email
* the recipient addresses
* the text used to prefix the subject line

The email includes information about the current request, session, and
environment, and also gives a backtrace of the exception.

Installation
---

You can use the latest ExceptionNotification gem with Rails 3, by adding
the following line in your Gemfile

    gem 'exception_notification'

As of Rails 3 ExceptionNotification is used as a rack middleware, so you can
configure its options on your config.ru file, or in the environment you
want it to run. In most cases you would want ExceptionNotification to
run on production. You can make it work by

    Whatever::Application.config.middleware.use ExceptionNotifier,
      :email_prefix => "[Whatever] ",
      :sender_address => %{"notifier" <notifier@example.com>},
      :exception_recipients => %w{exceptions@example.com}

Customization
---
By default subject includes exception message. Use :verbose_subject => false
to exclude it from subject.
By default, the notification email includes four parts: request, session,
environment, and backtrace (in that order). You can customize how each of those
sections are rendered by placing a partial named for that part in your
app/views/exception_notifier directory (e.g., _session.rhtml). Each partial has
access to the following variables:

    @controller     # the controller that caused the error
    @request        # the current request object
    @exception      # the exception that was raised
    @backtrace      # a sanitized version of the exception's backtrace
    @data           # a hash of optional data values that were passed to the notifier
    @sections       # the array of sections to include in the email

You can reorder the sections, or exclude sections completely, by altering the
ExceptionNotifier.sections variable. You can even add new sections that
describe application-specific data--just add the section's name to the list
(wherever you'd like), and define the corresponding partial. 
   
    #Example with two new added sections
    Whatever::Application.config.middleware.use ExceptionNotifier,
	   :email_prefix => "[Whatever] ",
	   :sender_address => %{"notifier" <notifier@example.com>},
	   :exception_recipients => %w{exceptions@example.com},
	   :sections => %w{my_section1 my_section2} + ExceptionNotifier::Notifier.default_sections

If your new section requires information that isn't available by default, make sure
it is made available to the email using the exception_data macro:

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

In the above case, @document and @person would be made available to the email
renderer, allowing your new section(s) to access and display them. See the
existing sections defined by the plugin for examples of how to write your own.

Background Notifications
---

If you want to send notifications from a background process like
DelayedJob, you should use the background_exception_notification method
like this:

    begin
      some code...
    rescue => e
      ExceptionNotifier::Notifier.background_exception_notification(e)
    end

Manually notify of exception
---

If your controller action manually handles an error, the notifier will never be
run. To manually notify of an error you can do something like the following:

    rescue_from Exception, :with => :server_error

    def server_error(exception)
      # Whatever code that handles the exception

      ExceptionNotifier::Notifier.exception_notification(request.env, exception).deliver
    end

Notification
---

After an exception notification has been delivered the rack environment variable
'exception_notifier.delivered' will be set to +true+.

Rails 2.3 stable and earlier
---

If you are running Rails 2.3 then see the branch for that: 
 
<a href="http://github.com/smartinez87/exception_notification/tree/2-3-stable">http://github.com/smartinez87/exception_notification/tree/2-3-stable</a>

If you are running pre-rack Rails then see this tag: 

<a href="http://github.com/smartinez87/exception_notification/tree/pre-2-3">http://github.com/smartinez87/exception_notification/tree/pre-2-3</a>

Support and tickets
---

<a href="https://github.com/smartinez87/exception_notification/issues">https://github.com/smartinez87/exception_notification/issues</a>

Copyright (c) 2005 Jamis Buck, released under the MIT license
