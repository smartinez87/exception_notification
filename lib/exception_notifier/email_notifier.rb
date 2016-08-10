require "active_support/core_ext/hash/reverse_merge"
require 'active_support/core_ext/time'
require 'action_mailer'
require 'action_dispatch'
require 'pp'
require 'objspace'

module ExceptionNotifier
  class EmailNotifier < BaseNotifier
    attr_accessor(:sender_address, :exception_recipients,
    :pre_callback, :post_callback,
    :email_prefix, :email_format, :sections, :background_sections,
    :verbose_subject, :normalize_subject, :delivery_method, :mailer_settings,
    :email_headers, :mailer_parent, :template_path, :deliver_with)

    module Mailer
      class MissingController
        def method_missing(*args, &block)
        end
      end

      def self.extended(base)
        base.class_eval do
          self.send(:include, ExceptionNotifier::BacktraceCleaner)

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
            @timestamp  = Time.current
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
            @timestamp = Time.current
            @sections  = @options[:background_sections]
            @data      = options[:data] || {}
            @env = @kontroller = nil

            compose_email
          end
          
           def shrink_sections
                 if ObjectSpace.memsize_of(sections_content) > 4294967296
 +                sections_content = sections_content.first(10).to_h
                 end
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

          helper_method :inspect_object

          def inspect_object(object)
            case object
              when Hash, Array
                object.inspect
              else
                object.to_s
            end
          end

          helper_method :safe_encode

          def safe_encode(value)
            value.encode("utf-8", invalid: :replace, undef: :replace, replace: "_")
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
              :delivery_method => @options[:delivery_method],
              :to => exception_recipients,
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
            if defined?(Rails) && Rails.respond_to?(:root)
              self.prepend_view_path Rails.root.nil? ? "app/views" : "#{Rails.root}/app/views"
            end
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

      options.reverse_merge(EmailNotifier.default_options).select{|k,v|[
        :sender_address, :exception_recipients,
        :pre_callback, :post_callback,
        :email_prefix, :email_format, :sections, :background_sections,
        :verbose_subject, :normalize_subject, :delivery_method, :mailer_settings,
        :email_headers, :mailer_parent, :template_path, :deliver_with].include?(k)}.each{|k,v| send("#{k}=", v)}
    end

    def options
      @options ||= {}.tap do |opts|
        self.instance_variables.each { |var| opts[var[1..-1].to_sym] = self.instance_variable_get(var) }
      end
    end

    def mailer
      @mailer ||= Class.new(mailer_parent.constantize).tap do |mailer|
        mailer.extend(EmailNotifier::Mailer)
        mailer.mailer_name = template_path
      end
    end

    def call(exception, options={})
      message = create_email(exception, options)

      # FIXME: use `if Gem::Version.new(ActionMailer::VERSION::STRING) < Gem::Version.new('4.1')`
      if deliver_with == :default
        if message.respond_to?(:deliver_now)
          message.deliver_now
        else
          message.deliver
        end
      else
        message.send(deliver_with)
      end
    end

    def create_email(exception, options={})
      env = options[:env]
      default_options = self.options
      if env.nil?
        send_notice(exception, options, nil, default_options) do |_, default_opts|
          mailer.background_exception_notification(exception, options, default_opts)
        end
      else
        send_notice(exception, options, nil, default_options) do |_, default_opts|
          mailer.exception_notification(env, exception, options, default_opts)
        end
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
        :template_path => 'exception_notifier',
        :deliver_with => :default
      }
    end

    def self.normalize_digits(string)
      string.gsub(/[0-9]+/, 'N')
    end
  end
end
