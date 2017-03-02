require 'digest/sha1'

module ExceptionNotifier::Throttling

  @min_notification_interval = 0

  class << self

    def ignore_exception?(exception)
      return false unless rails_cache_available?

      interval = min_notification_interval_for(exception)
      return false if interval <= 0

      key = ['exception-notification-throttling-', exception_signature(exception)].join('-')

      if Rails.cache.read(key)
        true
      else
        Rails.cache.write(key, true, expires_in: interval)
        false
      end
    end

    def min_notification_interval=(interval)
      @min_notification_interval = normalize_min_notification_interval(interval)
    end

    private

    attr_reader :min_notification_interval

    def rails_cache_available?
      defined?(Rails) && Rails.respond_to?(:cache)
    end

    def exception_signature(exception)
      signature = [exception.class, exception.message, exception.backtrace].join('')
      Digest::SHA1.hexdigest(signature)
    end

    def normalize_min_notification_interval(interval)
      return interval if interval.respond_to?(:call)

      begin
        interval.to_i
      rescue
        raise "Invalid min notification interval: #{interval.inspect}"
      end
    end

    def min_notification_interval_for(exception)
      interval = min_notification_interval
      if interval.respond_to?(:call)
        normalize_min_notification_interval(interval.call(exception))
      else
        interval
      end
    end
  end
end
