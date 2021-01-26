# frozen_string_literal: true

require 'active_support/core_ext/time'
require 'action_dispatch'

module ExceptionNotifier
  class Formatter
    include ExceptionNotifier::BacktraceCleaner

    attr_reader :app_name

    def initialize(exception, opts = {})
      @exception = exception

      @env = opts[:env]
      @errors_count = opts[:accumulated_errors_count].to_i
      @app_name = opts[:app_name] || rails_app_name
    end

    #
    # :warning: Error occurred in production :warning:
    # :warning: Error occurred :warning:
    #
    def title
      env = Rails.env if defined?(::Rails) && ::Rails.respond_to?(:env)

      if env
        "⚠️ Error occurred in #{env} ⚠️"
      else
        '⚠️ Error occurred ⚠️'
      end
    end

    #
    # A *NoMethodError* occurred.
    # 3 *NoMethodError* occurred.
    # A *NoMethodError* occurred in *home#index*.
    #
    def subtitle
      errors_text = if errors_count > 1
                      errors_count
                    else
                      exception.class.to_s =~ /^[aeiou]/i ? 'An' : 'A'
                    end

      in_action = " in *#{controller_and_action}*" if controller

      "#{errors_text} *#{exception.class}* occurred#{in_action}."
    end

    #
    #
    # *Request:*
    # ```
    # * url : https://www.example.com/
    # * http_method : GET
    # * ip_address : 127.0.0.1
    # * parameters : {"controller"=>"home", "action"=>"index"}
    # * timestamp : 2019-01-01 00:00:00 UTC
    # ```
    #
    def request_message
      request = ActionDispatch::Request.new(env) if env
      return unless request

      [
        '```',
        "* url : #{request.original_url}",
        "* http_method : #{request.method}",
        "* ip_address : #{request.remote_ip}",
        "* parameters : #{request.filtered_parameters}",
        "* timestamp : #{Time.current}",
        '```'
      ].join("\n")
    end

    #
    #
    # *Backtrace:*
    # ```
    # * app/controllers/my_controller.rb:99:in `specific_function'
    # * app/controllers/my_controller.rb:70:in `specific_param'
    # * app/controllers/my_controller.rb:53:in `my_controller_params'
    # ```
    #
    def backtrace_message
      backtrace = exception.backtrace ? clean_backtrace(exception) : nil

      return unless backtrace

      text = []

      text << '```'
      backtrace.first(3).each { |line| text << "* #{line}" }
      text << '```'

      text.join("\n")
    end

    #
    # home#index
    #
    def controller_and_action
      "#{controller.controller_name}##{controller.action_name}" if controller
    end

    private

    attr_reader :exception, :env, :errors_count

    def rails_app_name
      return unless defined?(::Rails) && ::Rails.respond_to?(:application)

      
      if Rails::VERSION::MAJOR >= 6
        Rails.application.class.module_parent_name.underscore
      else
        Rails.application.class.parent_name.underscore
      end
    end

    def controller
      env['action_controller.instance'] if env
    end
  end
end
