module ExceptionNotifier
  class SlackNotifier
    include ExceptionNotifier::BacktraceCleaner
    DEFAULT_OPTIONS = {
      username: 'Exception Notifier',
      icon_emoji: ':fire:'
    }
    attr_accessor :slack_options

    def initialize(options)
      self.slack_options = options
    end

    def call(exception, options = {})
      env = options.fetch(:env, {})
      request = (env['REQUEST_METHOD'] ? ActionDispatch::Request.new(env) : nil)
      notifier.ping '', message_options(exception, request)
    end

    private

    def notifier
      @notifier ||= Slack::Notifier.new slack_options.fetch(:webhook_url)
    end

    def message_options(exception, request)
      title = "#{request.request_method} #{request.original_url}" if request
      options = DEFAULT_OPTIONS.merge(slack_options.slice(:channel, :username, :icon_emoji))
      options[:attachments] = [{
        color: 'danger',
        title: title,
        text: exception.message,
        fields: attachment_fields(exception, request),
        mrkdwn_in: %w(text title fallback fields)
      }]
      options
    end

    # see https://api.slack.com/docs/attachments
    def attachment_fields(exception, request)
      backtrace = clean_backtrace(exception).first(10).map { |s| "> #{s}" }.join("\n")
      fields = [
        attachment_field('Project', Rails.application.class.parent_name, short: true),
        attachment_field('Environment', Rails.env, short: true),
        attachment_field('Time', Time.zone.now.strftime('%Y-%m-%d %H:%M:%S'), short: true),
        attachment_field('Backtrace', backtrace, short: false)
      ]
      fields << attachment_field('Parameters', request.filtered_parameters.map { |k, v| "> #{k}=#{v}" }.join("\n"), short: false) if request
      fields
    end

    def attachment_field(title, value, short: false)
      {
        title: title,
        value: value,
        short: short
      }
    end
  end
end
