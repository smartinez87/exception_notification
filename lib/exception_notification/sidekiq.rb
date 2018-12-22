require 'sidekiq'

# Note: this class is only needed for Sidekiq version < 3.
module ExceptionNotification
  class Sidekiq
    def call(worker, msg, queue)
      begin
        yield
      rescue Exception => exception
        ExceptionNotifier.notify_exception(exception, data: { sidekiq: msg })
        raise exception
      end
    end

  end
end

if ::Sidekiq::VERSION < '3'
  ::Sidekiq.configure_server do |config|
    config.server_middleware do |chain|
      chain.add ::ExceptionNotification::Sidekiq
    end
  end
else
  ::Sidekiq.configure_server do |config|
    config.error_handlers << Proc.new { |ex, context|
      ExceptionNotifier.notify_exception(ex, data: { sidekiq: context })
    }
  end
end
