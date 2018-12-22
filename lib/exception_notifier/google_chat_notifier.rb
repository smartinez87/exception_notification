require 'action_dispatch'
require 'active_support/core_ext/time'
require 'httparty'

module ExceptionNotifier
  class GoogleChatNotifier < BaseNotifier
    include ExceptionNotifier::BacktraceCleaner

    def call(exception, opts = {})
      @options = base_options.merge(opts)
      @exception = exception

      HTTParty.post(
        options[:webhook_url],
        body: { text: body }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    end

    private

    attr_reader :options, :exception

    def body
      text = [
        header,
        "",
        "⚠️ Error 500 in #{Rails.env} ⚠️",
        "*#{exception.message.tr('`', "'")}*"
      ]

      text += message_request
      text += message_backtrace

      text.join("\n")
    end

    def header
      text = ["\nApplication: *#{app_name}*"]

      errors_text = errors_count > 1 ? errors_count : 'An'
      text << "#{errors_text} *#{exception.class}* occured#{controller_text}."

      text
    end

    def message_request
      return [] unless (env = options[:env])
      request = ActionDispatch::Request.new(env)

      [
        "",
        "*Request:*",
        "```",
        "* url : #{request.original_url}",
        "* http_method : #{request.method}",
        "* ip_address : #{request.remote_ip}",
        "* parameters : #{request.filtered_parameters}",
        "* timestamp : #{Time.current}",
        "```"
      ]
    end

    def message_backtrace
      backtrace = exception.backtrace ? clean_backtrace(exception) : nil

      return [] unless backtrace

      text = []

      text << ''
      text << "*Backtrace:*"
      text << "```"
      backtrace.first(3).each { |line| text << "* #{line}" }
      text << "```"

      text
    end

    def app_name
      @app_name ||= options[:app_name] || rails_app_name || "N/A"
    end

    def errors_count
      @errors_count ||= options[:accumulated_errors_count].to_i
    end

    def rails_app_name
      Rails.application.class.parent_name.underscore if defined?(Rails)
    end

    def controller_text
      env = options[:env]
      controller = env ? env['action_controller.instance'] : nil

      if controller
        " in *#{controller.controller_name}##{controller.action_name}*"
      end
    end
  end
end
