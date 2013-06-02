require 'active_support/deprecation'

module ExceptionNotifier
  class Notifier

    def self.exception_notification(env, exception, options={})
      ActiveSupport::Deprecation.warn "Please use ExceptionNotifier.notify_exception(exception, options.merge(:env => env))."
      ExceptionNotifier.registered_exception_notifier(:email).create_email(exception, options.merge(:env => env))
    end

    def self.background_exception_notification(exception, options={})
      ActiveSupport::Deprecation.warn "Please use ExceptionNotifier.notify_exception(exception, options)."
      ExceptionNotifier.registered_exception_notifier(:email).create_email(exception, options)
    end
  end
end
