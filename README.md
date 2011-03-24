Exception Notifier Plugin for Rails
====

The Exception Notifier plugin provides a mailer object and a default set of
templates for sending email notifications when errors occur in a Rails
application. The plugin is configurable, allowing programmers to specify:

* the sender address of the email
* the recipient addresses
* the text used to prefix the subject line

The email includes information about the current request, session, and
environment, and also gives a backtrace of the exception.

Usage
---

As of Rails 3 ExceptionNotifier is used as a rack middleware

    Whatever::Application.config.middleware.use ExceptionNotifier,
      :email_prefix => "[Whatever] ",
      :sender_address => %{"notifier" <notifier@example.com>},
      :exception_recipients => %w{exceptions@example.com}

Customization
---

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
(whereever you'd like), and define the corresponding partial. Then, if your
new section requires information that isn't available by default, make sure
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

Notification
---

After an exception notification has been delivered the rack environment variable
'exception_notifier.delivered' will be set to +true+.

Rails 2.3 stable and earlier
---

If you are running Rails 2.3 then see the branch for that: 
 
<a href="http://github.com/rails/exception_notification/tree/2-3-stable">http://github.com/rails/exception_notification/tree/2-3-stable</a>

If you are running pre-rack Rails then see this tag: 

<a href="http://github.com/rails/exception_notification/tree/pre-2-3">http://github.com/rails/exception_notification/tree/pre-2-3</a>

Support and tickets
---

<a href="https://github.com/smartinez87/exception_notification/issues">https://github.com/smartinez87/exception_notification/issues</a>

Copyright (c) 2005 Jamis Buck, released under the MIT license
