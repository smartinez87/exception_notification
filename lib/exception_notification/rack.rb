module ExceptionNotification
  class Rack
    def initialize(app, options = {})
      @app = app

      ExceptionNotifier.ignored_exceptions = options.delete(:ignore_exceptions) if options.key?(:ignore_exceptions)

      if options.key?(:ignore_if)
        rack_ignore = options.delete(:ignore_if)
        ExceptionNotifier.ignore_if do |exception, options|
          options.key?(:env) && rack_ignore.call(options[:env], exception)
        end
      end

      if options.key?(:ignore_crawlers)
        ignore_crawlers = options.delete(:ignore_crawlers)
        ExceptionNotifier.ignore_if do |exception, options|
          options.key?(:env) && from_crawler(options[:env], ignore_crawlers)
        end
      end

      options.each do |notifier_name, options|
        ExceptionNotifier.register_exception_notifier(notifier_name, options)
      end
    end

    def call(env)
      @app.call(env)
    rescue Exception => exception
      if ExceptionNotifier.notify_exception(exception, :env => env)
        env['exception_notifier.delivered'] = true
      end
      raise exception
    end

    private

    def from_crawler(env, ignored_crawlers)
      agent = env['HTTP_USER_AGENT']
      Array(ignored_crawlers).any? do |crawler|
        agent =~ Regexp.new(crawler)
      end
    end
  end
end
