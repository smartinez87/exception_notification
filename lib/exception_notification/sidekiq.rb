# frozen_string_literal: true

require 'sidekiq'

# Note: this class is only needed for Sidekiq version < 3.
module ExceptionNotification
  class Sidekiq
    def call(_worker, msg, _queue)
      yield
    rescue Exception => e
      ExceptionNotifier.notify_exception(e, data: { sidekiq: msg })
      raise e
    end
  end
end

if ::Sidekiq::VERSION < '3'
  ::Sidekiq.configure_server do |config|
    config.server_middleware do |chain|
      chain.add ::ExceptionNotification::Sidekiq
    end
  end
elsif ::Sidekiq::VERSION < '7.1.5'
  ::Sidekiq.configure_server do |config|
    config.error_handlers << proc do |ex, context|
      ExceptionNotifier.notify_exception(ex, data: { sidekiq: context })
    end
  end
else
  ::Sidekiq.configure_server do |config|
    config.error_handlers << proc do |ex, context, config|
      ExceptionNotifier.notify_exception(ex, data: { sidekiq: { context: context, config: config } })
    end
  end
end
