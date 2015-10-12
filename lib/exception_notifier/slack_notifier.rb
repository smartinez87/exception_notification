module ExceptionNotifier
  class SlackNotifier
    include BacktraceCleaner
    DEFAULT_OPTIONS = {
      username: 'Exception Notifier',
      icon_emoji: ':fire:'
    }
    attr_accessor :slack_options

    def initialize(options)
      self.slack_options = options
    end

    def call(exception, options = {})
      notifier.ping '', message_options(exception, options)
    end

    private

    def notifier
      @notifier ||= Slack::Notifier.new slack_options.fetch(:webhook_url)
    end

    def extract_data_from_options(options)
      options.fetch(:data, {}).tap do |data|
        data.merge!(error_data_for_request(options))
        data.merge!(error_data_for_rails)
      end
    end

    # see https://api.slack.com/docs/formatting
    # see https://api.slack.com/incoming-webhooks
    def message_options(exception, opts)
      data = extract_data_from_options(opts)
      DEFAULT_OPTIONS.merge(slack_options).merge(opts).slice(:channel, :username, :icon_emoji).tap do |options|
        options[:attachments] = [{
          color: 'danger',
          title: exception.message,
          text: exception_backtrace(exception),
          fallback: data_to_text(data),
          fields: attachment_fields(data)
        }]
      end
    end

    def data_to_text(data)
      data.map do |key, value|
        [key, value].join(': ')
      end.join("\n")
    end

    # see https://api.slack.com/docs/attachments
    def attachment_fields(data)
      data.map do |key, value|
        attachment_field(key, value.to_s, short: false)
      end
    end

    def attachment_field(title, value, short: false)
      {
        title: title,
        value: value,
        short: short
      }
    end

    def exception_backtrace(exception)
      clean_backtrace(exception).first(10).join("\n")
    end

    def error_data_for_rails
      return {} unless defined?(Rails)
      {
        'Project' => Rails.application.class.parent_name,
        'Environment' => Rails.env
      }
    end

    def error_data_for_request(options)
      env = options.fetch(:env, {})
      return {} unless env['REQUEST_METHOD']
      request = ActionDispatch::Request.new(env)
      request.env.fetch('exception_notifier.exception_data', {}).merge(
        'Request Method' => request.request_method,
        'Request URL' => request.original_url
      )
    end
  end
end
