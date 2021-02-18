# frozen_string_literal: true

module ExceptionNotifier
  class SlackNotifier < BaseNotifier
    include ExceptionNotifier::BacktraceCleaner

    attr_accessor :notifier

    def initialize(options)
      super
      begin
        @ignore_data_if = options[:ignore_data_if]
        @backtrace_lines = options.fetch(:backtrace_lines, 10)
        @clean_backtrace = options.delete(:clean_backtrace) { true }
        @additional_fields = options[:additional_fields]

        webhook_url = options.fetch(:webhook_url)
        @message_opts = options.fetch(:additional_parameters, {})
        @color = @message_opts.delete(:color) { 'danger' }
        @notifier = Slack::Notifier.new webhook_url, options
      rescue StandardError
        @notifier = nil
      end
    end

    def call(exception, options = {})
      clean_message = exception.message.tr('`', "'")
      attchs = attchs(exception, clean_message, options)

      return unless valid?

      args = [exception, options, clean_message, @message_opts.merge(attachments: attchs)]
      send_notice(*args) do |_msg, message_opts|
        message_opts[:channel] = options[:channel] if options.key?(:channel)

        @notifier.ping '', message_opts
      end
    end

    protected

    def valid?
      !@notifier.nil?
    end

    def deep_reject(hash, block)
      hash.each do |k, v|
        deep_reject(v, block) if v.is_a?(Hash)

        hash.delete(k) if block.call(k, v)
      end
    end

    private

    def attchs(exception, clean_message, options)
      text, data = information_from_options(exception.class, options)
      backtrace = if exception.backtrace
        @clean_backtrace ? clean_backtrace(exception) : exception.backtrace
      end
      fields = fields(clean_message, backtrace, data)

      [color: @color, text: text, fields: fields, mrkdwn_in: %w[text fields]]
    end

    def information_from_options(exception_class, options)
      errors_count = options[:accumulated_errors_count].to_i

      measure_word = if errors_count > 1
                       errors_count
                     else
                       exception_class.to_s =~ /^[aeiou]/i ? 'An' : 'A'
                     end

      exception_name = "*#{measure_word}* `#{exception_class}`"
      env = options[:env]

      if env.nil?
        data = options[:data] || {}
        text = "#{exception_name} *occured in background*\n"
      else
        data = (env['exception_notifier.exception_data'] || {}).merge(options[:data] || {})

        kontroller = env['action_controller.instance']
        request = "#{env['REQUEST_METHOD']} <#{env['REQUEST_URI']}>"
        text = "#{exception_name} *occurred while* `#{request}`"
        text += " *was processed by* `#{kontroller.controller_name}##{kontroller.action_name}`" if kontroller
        text += "\n"
      end

      [text, data]
    end

    def fields(clean_message, backtrace, data)
      fields = [
        { title: 'Exception', value: clean_message },
        { title: 'Hostname', value: Socket.gethostname }
      ]

      if backtrace
        formatted_backtrace = "```#{backtrace.first(@backtrace_lines).join("\n")}```"
        fields << { title: 'Backtrace', value: formatted_backtrace }
      end

      unless data.empty?
        deep_reject(data, @ignore_data_if) if @ignore_data_if.is_a?(Proc)
        data_string = data.map { |k, v| "#{k}: #{v}" }.join("\n")
        fields << { title: 'Data', value: "```#{data_string}```" }
      end

      fields.concat(@additional_fields) if @additional_fields

      fields
    end
  end
end
