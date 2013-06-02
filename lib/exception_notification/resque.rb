require 'resque/failure/base'

module ExceptionNotification
  class Resque < Resque::Failure::Base

    def self.count
      Stat[:failed]
    end

    def save
      data = {
        :failed_at     => Time.now.to_s,
        :queue         => queue,
        :worker        => worker.to_s,
        :payload       => payload,
        :error_class   => exception.class.name,
        :error_message => exception.message
      }

      ExceptionNotifier.notify_exception(exception, :data => { :resque => data })
    end

  end
end
