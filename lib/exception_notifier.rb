require 'action_dispatch'

class ExceptionNotifier

  autoload :Notifier, 'exception_notifier/notifier'
  autoload :EmailNotifier, 'exception_notifier/email_notifier'
  autoload :CampfireNotifier, 'exception_notifier/campfire_notifier'
  autoload :WebhookNotifier, 'exception_notifier/webhook_notifier'

  class UndefinedNotifierError < StandardError; end

  class << self
    @@notifiers = {}

    def default_ignore_exceptions
      ['ActiveRecord::RecordNotFound', 'AbstractController::ActionNotFound', 'ActionController::RoutingError']
    end

    def default_ignore_crawlers
      []
    end

    def notify_exception(exception, options={})
      selected_notifiers = options.delete(:notifiers) || notifiers
      [*selected_notifiers].each do |notifier|
        fire_notification(notifier, exception, options)
      end
    end

    def register_exception_notifier(name, notifier)
      @@notifiers[name] = notifier
    end

    def unregister_exception_notifier(name)
      @@notifiers.delete(name)
    end

    def registered_exception_notifier(name)
      @@notifiers[name]
    end

    def notifiers
      @@notifiers.keys
    end

    private
    def fire_notification(notifier_name, exception, options)
      notifier = registered_exception_notifier(notifier_name)
      notifier.call(exception, options)
    rescue
      false
    end
  end

  def initialize(app, options = {})
    @app = app

    @options = {}
    @options[:ignore_exceptions] = options.delete(:ignore_exceptions) || self.class.default_ignore_exceptions
    @options[:ignore_crawlers]   = options.delete(:ignore_crawlers) || self.class.default_ignore_crawlers
    @options[:ignore_if]         = options.delete(:ignore_if) || lambda { |env, e| false }

    options = make_options_backward_compatible(options)
    options.each do |notifier_name, options|
      create_and_register_notifier(notifier_name, options)
    end
  end

  def call(env)
    @app.call(env)
  rescue Exception => exception
    options = @options.dup

    unless ignored_exception(options[:ignore_exceptions], exception)       ||
           from_crawler(options[:ignore_crawlers], env['HTTP_USER_AGENT']) ||
           conditionally_ignored(options[:ignore_if], env, exception)
      ExceptionNotifier.notify_exception(exception, options.reverse_merge(:env => env))
      env['exception_notifier.delivered'] = true
    end

    raise exception
  end

  private

  def ignored_exception(ignore_array, exception)
    Array.wrap(ignore_array).map(&:to_s).include?(exception.class.name)
  end

  def from_crawler(ignore_array, agent)
    ignore_array.each do |crawler|
      return true if (agent =~ Regexp.new(crawler))
    end unless ignore_array.blank?
    false
  end

  def conditionally_ignored(ignore_proc, env, exception)
    ignore_proc.call(env, exception)
  rescue Exception
    false
  end

  def create_and_register_notifier(name, options)
    notifier_classname = "#{name}_notifier".camelize
    notifier_class = ExceptionNotifier.const_get(notifier_classname)
    notifier = notifier_class.new(options)
    ExceptionNotifier.register_exception_notifier(name, notifier)
  rescue NameError => e
    raise UndefinedNotifierError, "No notifier named '#{name}' was found. Please, revise your configuration options. Cause: #{e.message}"
  end

  def make_options_backward_compatible(options)
    email_options_names = [:sender_address, :exception_recipients,
        :email_prefix, :email_format, :sections, :background_sections,
        :verbose_subject, :normalize_subject, :smtp_settings, :email_headers]

    if email_options_names.any?{|eo| options.has_key?(eo) }
      ActiveSupport::Deprecation.warn "You are using an old configuration style for ExceptionNotifier middleware. Please, revise your configuration options later."
      email_options = options.select{ |k,v| email_options_names.include?(k) }
      options.reject!{ |k,v| email_options_names.include?(k) }
      options[:email] = email_options
    end

    options
  end
end
