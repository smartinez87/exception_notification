module ExceptionNotification
  class Engine < ::Rails::Engine
    config.exception_notification = ExceptionNotifier
    config.exception_notification.logger = Rails.logger
    config.exception_notification.error_grouping_cache = Rails.cache

    config.app_middleware.use ExceptionNotification::Rack
  end
end
