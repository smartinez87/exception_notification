module ExceptionNotification
  class Engine < ::Rails::Engine
    config.exception_notification = ExceptionNotifier
    config.exception_notification.logger = Rails.logger

    config.app_middleware.use ExceptionNotification::Rack
  end
end
