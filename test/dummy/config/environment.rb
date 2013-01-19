# Load the rails application
require File.expand_path('../application', __FILE__)

Dummy::Application.config.middleware.use ExceptionNotifier,
  :email_prefix => "[Dummy ERROR] ",
  :sender_address => %{"Dummy Notifier" <dummynotifier@example.com>},
  :exception_recipients => %w{dummyexceptions@example.com},
  :email_headers => { "X-Custom-Header" => "foobar" },
  :sections => ['new_section', 'request', 'session', 'environment', 'backtrace'],
  :background_sections => %w(new_bkg_section) + ExceptionNotifier::Notifier.default_background_sections

# Initialize the rails application
Dummy::Application.initialize!
