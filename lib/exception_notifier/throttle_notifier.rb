module ExceptionNotifier
  class ThrottleNotifier
    def initialize options={}
      @notifier = ExceptionNotifier.create_notifier(options[:notifier], options[:notifier_options] || {})
      @max_notifications_per_hour = 3
      @past_exceptions = Hash.new {|h,k| h[k] = []}
    end

    def call(exception, options={})
      key = exception.class.to_s.each_byte.reduce(&:+)

      past_times = @past_exceptions[key]
      past_times.reject! {|t| (Time.now - t) >= 3600}
      past_times << Time.now

      if past_times.size <= @max_notifications_per_hour
        @notifier.call exception, options
      else
        ExceptionNotifier::logger.warn "An exception occurred (#{exception}) and the notifier #{@notifier} was throttled."
      end
    end
  end
end
