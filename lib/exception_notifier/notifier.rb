require 'action_mailer'
require 'pp'

class ExceptionNotifier
  class Notifier < ActionMailer::Base
    self.mailer_name = 'exception_notifier'

    #Append application view path to the ExceptionNotifier lookup context.
    self.append_view_path "#{File.dirname(__FILE__)}/views"

    class << self
      attr_writer :default_sender_address
      attr_writer :default_exception_recipients
      attr_writer :default_email_prefix
      attr_writer :default_email_format
      attr_writer :default_sections
      attr_writer :default_background_sections
      attr_writer :default_verbose_subject
      attr_writer :default_normalize_subject
      attr_writer :default_smtp_settings
      attr_writer :default_email_headers

      def default_sender_address
        @default_sender_address || %("Exception Notifier" <exception.notifier@default.com>)
      end

      def default_exception_recipients
        @default_exception_recipients || []
      end

      def default_email_prefix
        @default_email_prefix || "[ERROR] "
      end

      def default_email_format
        @default_email_format || :text
      end

      def default_sections
        @default_sections || %w(request session environment backtrace)
      end

      def default_background_sections
        @default_background_sections || %w(backtrace data)
      end

      def default_verbose_subject
        @default_verbose_subject.nil? || @default_verbose_subject
      end

      def default_normalize_subject
        @default_normalize_prefix || false
      end

      def default_smtp_settings
        @default_smtp_settings || nil
      end

      def default_email_headers
        @default_email_headers || {}
      end

      def default_options
        { :sender_address => default_sender_address,
          :exception_recipients => default_exception_recipients,
          :email_prefix => default_email_prefix,
          :email_format => default_email_format,
          :sections => default_sections,
          :background_sections => default_background_sections,
          :verbose_subject => default_verbose_subject,
          :normalize_subject => default_normalize_subject,
          :template_path => mailer_name,
          :smtp_settings => default_smtp_settings,
          :email_headers => default_email_headers }
      end

      def normalize_digits(string)
        string.gsub(/[0-9]+/, 'N')
      end
    end

    class MissingController
      def method_missing(*args, &block)
      end
    end

    def exception_notification(env, exception, options={})
      load_custom_views

      @env        = env
      @exception  = exception
      @options    = options.reverse_merge(env['exception_notifier.options'] || {}).reverse_merge(self.class.default_options)
      @kontroller = env['action_controller.instance'] || MissingController.new
      @request    = ActionDispatch::Request.new(env)
      @backtrace  = exception.backtrace ? clean_backtrace(exception) : []
      @sections   = @options[:sections]
      @data       = (env['exception_notifier.exception_data'] || {}).merge(options[:data] || {})
      @sections   = @sections + %w(data) unless @data.empty?
      
      compose_email
    end

    def background_exception_notification(exception, options={})
      load_custom_views

      if @notifier = Rails.application.config.middleware.detect{ |x| x.klass == ExceptionNotifier }
        @options   = options.reverse_merge(@notifier.args.first || {}).reverse_merge(self.class.default_options)
        @exception = exception
        @backtrace = exception.backtrace || []
        @sections  = @options[:background_sections]
        @data      = options[:data] || {}

        compose_email
      end
    end

    private

    def compose_subject
      subject = "#{@options[:email_prefix]}"
      subject << "#{@kontroller.controller_name}##{@kontroller.action_name}" if @kontroller
      subject << " (#{@exception.class})"
      subject << " #{@exception.message.inspect}" if @options[:verbose_subject]
      subject = normalize_digits(subject) if @options[:normalize_subject]
      subject.length > 120 ? subject[0...120] + "..." : subject
    end

    def set_data_variables
      @data.each do |name, value|
        instance_variable_set("@#{name}", value)
      end
    end

    def clean_backtrace(exception)
      if Rails.respond_to?(:backtrace_cleaner)
       Rails.backtrace_cleaner.send(:filter, exception.backtrace)
      else
       exception.backtrace
      end
    end

    helper_method :inspect_object

    def inspect_object(object)
      case object
      when Hash, Array
        object.inspect
      when ActionController::Base
        "#{object.controller_name}##{object.action_name}"
      else
        object.to_s
      end
    end

    def html_mail?
      @options[:email_format] == :html
    end

    def compose_email
      set_data_variables
      subject = compose_subject
      name = @env.nil? ? 'background_exception_notification' : 'exception_notification'

      headers = {
        :to => @options[:exception_recipients], 
        :from => @options[:sender_address],
        :subject => subject, 
        :template_name => name
      }.merge(@options[:email_headers])

      mail = mail(headers) do |format|
        format.text
        format.html if html_mail?
      end
      
      mail.delivery_method.settings.merge!(@options[:smtp_settings]) if @options[:smtp_settings]
      
      mail
    end

    def load_custom_views
      self.prepend_view_path Rails.root.nil? ? "app/views" : "#{Rails.root}/app/views" if defined?(Rails)
    end
  end
end
