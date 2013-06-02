require 'sidekiq'

module ExceptionNotification
  class Sidekiq

    def call(worker, msg, queue)
      begin
        yield
      rescue Exception => exception
        ExceptionNotifier.notify_exception(exception, :data => { :sidekiq => msg })
        raise exception
      end
    end

  end
end

::Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add ::ExceptionNotification::Sidekiq
  end
end
