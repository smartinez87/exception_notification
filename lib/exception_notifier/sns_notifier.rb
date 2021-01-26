# frozen_string_literal: true

module ExceptionNotifier
  class SnsNotifier < BaseNotifier
    def initialize(options)
      super

      raise ArgumentError, "You must provide 'region' option" unless options[:region]
      raise ArgumentError, "You must provide 'access_key_id' option" unless options[:access_key_id]
      raise ArgumentError, "You must provide 'secret_access_key' option" unless options[:secret_access_key]

      @notifier = Aws::SNS::Client.new(
        region: options[:region],
        access_key_id: options[:access_key_id],
        secret_access_key: options[:secret_access_key]
      )
      @options = default_options.merge(options)
    end

    def call(exception, custom_opts = {})
      custom_options = options.merge(custom_opts)

      subject = build_subject(exception, custom_options)
      message = build_message(exception, custom_options)

      notifier.publish(
        topic_arn: custom_options[:topic_arn],
        message: message,
        subject: subject
      )
    end

    private

    attr_reader :notifier, :options

    def build_subject(exception, options)
      subject =
        "#{options[:sns_prefix]} - #{accumulated_exception_name(exception, options)} occurred"
      subject.length > 120 ? subject[0...120] + '...' : subject
    end

    def build_message(exception, options)
      exception_name = accumulated_exception_name(exception, options)

      if options[:env].nil?
        text = "#{exception_name} occured in background\n"
        data = options[:data] || {}
      else
        env = options[:env]

        kontroller = env['action_controller.instance']
        data = (env['exception_notifier.exception_data'] || {}).merge(options[:data] || {})
        request = "#{env['REQUEST_METHOD']} <#{env['REQUEST_URI']}>"

        text = "#{exception_name} occurred while #{request}"
        text += " was processed by #{kontroller.controller_name}##{kontroller.action_name}\n" if kontroller
      end

      text += "Exception: #{exception.message}\n"
      text += "Hostname: #{Socket.gethostname}\n"
      text += "Data: #{data}\n"

      return unless exception.backtrace

      formatted_backtrace = exception.backtrace.first(options[:backtrace_lines]).join("\n").to_s
      text + "Backtrace:\n#{formatted_backtrace}\n"
    end

    def accumulated_exception_name(exception, options)
      errors_count = options[:accumulated_errors_count].to_i

      measure_word = if errors_count > 1
                       errors_count
                     else
                       exception.class.to_s =~ /^[aeiou]/i ? 'An' : 'A'
                     end

      "#{measure_word} #{exception.class}"
    end

    def default_options
      {
        sns_prefix: '[ERROR]',
        backtrace_lines: 10
      }
    end
  end
end
