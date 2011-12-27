require 'action_mailer'
require 'pp'

class ExceptionNotifier
  class Notifier < ActionMailer::Base
    self.mailer_name = 'exception_notifier'

    #Append application view path to the ExceptionNotifier lookup context.
    self.append_view_path Rails.root.nil? ? "app/views" : "#{Rails.root}/app/views"  if defined?(Rails)
    self.append_view_path "#{File.dirname(__FILE__)}/views"

    class << self
      attr_writer :default_sender_address
      attr_writer :default_exception_recipients
      attr_writer :default_email_prefix
      attr_writer :default_sections
      attr_writer :default_background_sections
      attr_writer :default_verbose_subject

      def default_sender_address
        @default_sender_address || %("Exception Notifier" <exception.notifier@default.com>)
      end

      def default_exception_recipients
        @default_exception_recipients || []
      end

      def default_email_prefix
        @default_email_prefix || "[ERROR] "
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

      def default_options
        { :sender_address => default_sender_address,
          :exception_recipients => default_exception_recipients,
          :email_prefix => default_email_prefix,
          :sections => default_sections,
          :background_sections => default_background_sections,
          :verbose_subject => default_verbose_subject }
      end
    end

    class MissingController
      def method_missing(*args, &block)
      end
    end

    def exception_notification(env, exception)
      @env        = env
      @exception  = exception
      @options    = (env['exception_notifier.options'] || {}).reverse_merge(self.class.default_options)
      @kontroller = env['action_controller.instance'] || MissingController.new
      @request    = ActionDispatch::Request.new(env)
      @backtrace  = exception.backtrace ? clean_backtrace(exception) : []
      @sections   = @options[:sections]
      data        = env['exception_notifier.exception_data'] || {}

      data.each do |name, value|
        instance_variable_set("@#{name}", value)
      end
      subject = compose_subject(exception, @kontroller)

      mail(:to => @options[:exception_recipients], :from => @options[:sender_address], :subject => subject) do |format|
        format.text { render "#{mailer_name}/exception_notification" }
      end
    end

    def background_exception_notification(exception, data={})
      if @notifier = Rails.application.config.middleware.detect{ |x| x.klass == ExceptionNotifier }
        @options = (@notifier.args.first || {}).reverse_merge(self.class.default_options)
        @exception = exception
        @backtrace = exception.backtrace || []
        @sections = @options[:background_sections]
        @data = data

        data.each do |name, value|
          instance_variable_set("@#{name}", value)
        end
        subject  = compose_subject(exception)

        mail(:to => @options[:exception_recipients], :from => @options[:sender_address], :subject => subject) do |format|
          format.text { render "#{mailer_name}/background_exception_notification" }
        end.deliver
      end
    end

    private

    def compose_subject(exception, kontroller=nil)
      subject = "#{@options[:email_prefix]}"
      subject << "#{kontroller.controller_name}##{kontroller.action_name}" if kontroller
      subject << " (#{exception.class})"
      subject << " #{exception.message.inspect}" if @options[:verbose_subject]
      subject.length > 120 ? subject[0...120] + "..." : subject
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
  end
end
