module ExceptionNotification
  class Rack
    class CascadePassException < Exception; end

    def initialize(app, options = {})
      @app = app

      if options.key?(:ignore_exceptions)
        ExceptionNotifier.ignored_exceptions = options.delete(:ignore_exceptions)
      end

      if options.key?(:min_notification_interval)
        ExceptionNotifier.min_notification_interval = options.delete(:min_notification_interval)
      end

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

      @ignore_cascade_pass = options.delete(:ignore_cascade_pass) { true }

      options.each do |notifier_name, options|
        ExceptionNotifier.register_exception_notifier(notifier_name, options)
      end
    end

    def call(env)
      _, headers, _ = response = @app.call(env)

      if !@ignore_cascade_pass && headers['X-Cascade'] == 'pass'
        msg = "This exception means that the preceding Rack middleware set the 'X-Cascade' header to 'pass' -- in " <<
          "Rails, this often means that the route was not found (404 error)."
        raise CascadePassException, msg
      end

      response
    rescue Exception => exception
      if ExceptionNotifier.notify_exception(exception, :env => env)
        env['exception_notifier.delivered'] = true
      end

      raise exception unless exception.is_a?(CascadePassException)
      response
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
