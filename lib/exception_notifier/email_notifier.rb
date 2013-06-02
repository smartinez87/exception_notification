require 'action_mailer'
require 'action_dispatch'
require 'pp'

module ExceptionNotifier
  class EmailNotifier < Struct.new(:sender_address, :exception_recipients,
    :email_prefix, :email_format, :sections, :background_sections,
    :verbose_subject, :normalize_subject, :delivery_method, :mailer_settings,
    :email_headers, :mailer_parent, :template_path)

    module Mailer
      class MissingController
        def method_missing(*args, &block)
        end
      end

      def self.extended(base)
        base.class_eval do
          # Append application view path to the ExceptionNotifier lookup context.
          self.append_view_path "#{File.dirname(__FILE__)}/views"

          def exception_notification(env, exception, options={}, default_options={})
            load_custom_views

            @env        = env
            @exception  = exception
            @options    = options.reverse_merge(env['exception_notifier.options'] || {}).reverse_merge(default_options)
            @kontroller = env['action_controller.instance'] || MissingController.new
            @request    = ActionDispatch::Request.new(env)
            @backtrace  = exception.backtrace ? clean_backtrace(exception) : []
            @sections   = @options[:sections]
            @data       = (env['exception_notifier.exception_data'] || {}).merge(options[:data] || {})
            @sections   = @sections + %w(data) unless @data.empty?

            compose_email
          end

          def background_exception_notification(exception, options={}, default_options={})
            load_custom_views

            @exception = exception
            @options   = options.reverse_merge(default_options)
            @backtrace = exception.backtrace || []
            @sections  = @options[:background_sections]
            @data      = options[:data] || {}

            compose_email
          end

          private

          def compose_subject
            subject = "#{@options[:email_prefix]}"
            subject << "#{@kontroller.controller_name}##{@kontroller.action_name}" if @kontroller
            subject << " (#{@exception.class})"
            subject << " #{@exception.message.inspect}" if @options[:verbose_subject]
            subject = EmailNotifier.normalize_digits(subject) if @options[:normalize_subject]
            subject.length > 120 ? subject[0...120] + "..." : subject
          end

          def set_data_variables
            @data.each do |name, value|
              instance_variable_set("@#{name}", value)
            end
          end

          def clean_backtrace(exception)
            if defined?(Rails) && Rails.respond_to?(:backtrace_cleaner)
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
                :delivery_method => @options[:delivery_method],
                :to => @options[:exception_recipients],
                :from => @options[:sender_address],
                :subject => subject,
                :template_name => name
            }.merge(@options[:email_headers])

            mail = mail(headers) do |format|
              format.text
              format.html if html_mail?
            end

            mail.delivery_method.settings.merge!(@options[:mailer_settings]) if @options[:mailer_settings]

            mail
          end

          def load_custom_views
            self.prepend_view_path Rails.root.nil? ? "app/views" : "#{Rails.root}/app/views" if defined?(Rails)
          end
        end
      end
    end

    def initialize(options)
      delivery_method = (options[:delivery_method] || :smtp)
      mailer_settings_key = "#{delivery_method}_settings".to_sym
      options[:mailer_settings] = options.delete(mailer_settings_key)

      super(*options.reverse_merge(EmailNotifier.default_options).values_at(
        :sender_address, :exception_recipients,
        :email_prefix, :email_format, :sections, :background_sections,
        :verbose_subject, :normalize_subject, :delivery_method, :mailer_settings,
        :email_headers, :mailer_parent, :template_path))
    end

    def options
      @options ||= {}.tap do |opts|
        each_pair { |k,v| opts[k] = v }
      end
    end

    def mailer
      @mailer ||= Class.new(mailer_parent.constantize).tap do |mailer|
        mailer.extend(EmailNotifier::Mailer)
        mailer.mailer_name = template_path
      end
    end

    def call(exception, options={})
      create_email(exception, options).deliver
    end

    def create_email(exception, options={})
      env = options[:env]
      default_options = self.options
      if env.nil?
        mailer.background_exception_notification(exception, options, default_options)
      else
        mailer.exception_notification(env, exception, options, default_options)
      end
    end

    def self.default_options
      {
        :sender_address => %("Exception Notifier" <exception.notifier@example.com>),
        :exception_recipients => [],
        :email_prefix => "[ERROR] ",
        :email_format => :text,
        :sections => %w(request session environment backtrace),
        :background_sections => %w(backtrace data),
        :verbose_subject => true,
        :normalize_subject => false,
        :delivery_method => nil,
        :mailer_settings => nil,
        :email_headers => {},
        :mailer_parent => 'ActionMailer::Base',
        :template_path => 'exception_notifier'
      }
    end

    def self.normalize_digits(string)
      string.gsub(/[0-9]+/, 'N')
    end
  end
end
