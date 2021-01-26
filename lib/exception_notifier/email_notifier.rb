# frozen_string_literal: true

require 'active_support/core_ext/time'
require 'action_mailer'
require 'action_dispatch'
require 'pp'

module ExceptionNotifier
  class EmailNotifier < BaseNotifier
    DEFAULT_OPTIONS = {
      sender_address: %("Exception Notifier" <exception.notifier@example.com>),
      exception_recipients: [],
      email_prefix: '[ERROR] ',
      email_format: :text,
      sections: %w[request session environment backtrace],
      background_sections: %w[backtrace data],
      verbose_subject: true,
      normalize_subject: false,
      include_controller_and_action_names_in_subject: true,
      delivery_method: nil,
      mailer_settings: nil,
      email_headers: {},
      mailer_parent: 'ActionMailer::Base',
      template_path: 'exception_notifier',
      deliver_with: nil
    }.freeze

    module Mailer
      class MissingController
        def method_missing(*args, &block); end
      end

      def self.extended(base)
        base.class_eval do
          send(:include, ExceptionNotifier::BacktraceCleaner)

          # Append application view path to the ExceptionNotifier lookup context.
          append_view_path "#{File.dirname(__FILE__)}/views"

          def exception_notification(env, exception, options = {}, default_options = {})
            load_custom_views

            @env        = env
            @exception  = exception

            env_options = env['exception_notifier.options'] || {}
            @options    = default_options.merge(env_options).merge(options)

            @kontroller = env['action_controller.instance'] || MissingController.new
            @request    = ActionDispatch::Request.new(env)
            @backtrace  = exception.backtrace ? clean_backtrace(exception) : []
            @timestamp  = Time.current
            @sections   = @options[:sections]
            @data       = (env['exception_notifier.exception_data'] || {}).merge(options[:data] || {})
            @sections += %w[data] unless @data.empty?

            compose_email
          end

          def background_exception_notification(exception, options = {}, default_options = {})
            load_custom_views

            @exception = exception
            @options   = default_options.merge(options).symbolize_keys
            @backtrace = exception.backtrace || []
            @timestamp = Time.current
            @sections  = @options[:background_sections]
            @data      = options[:data] || {}
            @env = @kontroller = nil

            compose_email
          end

          private

          def compose_subject
            subject = @options[:email_prefix].to_s.dup
            subject << "(#{@options[:accumulated_errors_count]} times)" if @options[:accumulated_errors_count].to_i > 1
            subject << "#{@kontroller.controller_name}##{@kontroller.action_name}" if include_controller?
            subject << " (#{@exception.class})"
            subject << " #{@exception.message.inspect}" if @options[:verbose_subject]
            subject = EmailNotifier.normalize_digits(subject) if @options[:normalize_subject]
            subject.length > 120 ? subject[0...120] + '...' : subject
          end

          def include_controller?
            @kontroller && @options[:include_controller_and_action_names_in_subject]
          end

          def set_data_variables
            @data.each do |name, value|
              instance_variable_set("@#{name}", value)
            end
          end

          helper_method :inspect_object

          def truncate(string, max)
            string.length > max ? "#{string[0...max]}..." : string
          end

          def inspect_object(object)
            case object
            when Hash, Array
              truncate(object.inspect, 300)
            else
              object.to_s
            end
          end

          helper_method :safe_encode

          def safe_encode(value)
            value.encode('utf-8', invalid: :replace, undef: :replace, replace: '_')
          end

          def html_mail?
            @options[:email_format] == :html
          end

          def compose_email
            set_data_variables
            subject = compose_subject
            name = @env.nil? ? 'background_exception_notification' : 'exception_notification'
            exception_recipients = maybe_call(@options[:exception_recipients])

            headers = {
              delivery_method: @options[:delivery_method],
              to: exception_recipients,
              from: @options[:sender_address],
              subject: subject,
              template_name: name
            }.merge(@options[:email_headers])

            mail = mail(headers) do |format|
              format.text
              format.html if html_mail?
            end

            mail.delivery_method.settings.merge!(@options[:mailer_settings]) if @options[:mailer_settings]

            mail
          end

          def load_custom_views
            return unless defined?(Rails) && Rails.respond_to?(:root)

            prepend_view_path Rails.root.nil? ? 'app/views' : "#{Rails.root}/app/views"
          end

          def maybe_call(maybe_proc)
            maybe_proc.respond_to?(:call) ? maybe_proc.call : maybe_proc
          end
        end
      end
    end

    def initialize(options)
      super

      delivery_method = (options[:delivery_method] || :smtp)
      mailer_settings_key = "#{delivery_method}_settings".to_sym
      options[:mailer_settings] = options.delete(mailer_settings_key)

      @base_options = DEFAULT_OPTIONS.merge(options)
    end

    def call(exception, options = {})
      message = create_email(exception, options)

      message.send(base_options[:deliver_with] || default_deliver_with(message))
    end

    def create_email(exception, options = {})
      env = options[:env]

      send_notice(exception, options, nil, base_options) do |_, default_opts|
        if env.nil?
          mailer.background_exception_notification(exception, options, default_opts)
        else
          mailer.exception_notification(env, exception, options, default_opts)
        end
      end
    end

    def self.normalize_digits(string)
      string.gsub(/[0-9]+/, 'N')
    end

    private

    def mailer
      @mailer ||= Class.new(base_options[:mailer_parent].constantize).tap do |mailer|
        mailer.extend(EmailNotifier::Mailer)
        mailer.mailer_name = base_options[:template_path]
      end
    end

    def default_deliver_with(message)
      # FIXME: use `if Gem::Version.new(ActionMailer::VERSION::STRING) < Gem::Version.new('4.1')`
      message.respond_to?(:deliver_now) ? :deliver_now : :deliver
    end
  end
end
