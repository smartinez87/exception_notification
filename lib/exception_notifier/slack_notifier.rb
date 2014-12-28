module ExceptionNotifier
  class SlackNotifier
    attr_accessor :slack_options

    def initialize(options)
      self.slack_options = options
    end

    def call(exception, options={})
      env = options[:env]

      link = env['HTTP_HOST'] + env['REQUEST_URI']
      title = "#{env['REQUEST_METHOD']} <http://#{link}|http://#{link}>\n"

      message = "------------------------------------------------------------------------------------------\n"
      message += "*Project:* #{Rails.application.class.parent_name}\n"
      message += "*Environment:* #{Rails.env}\n"
      message += "*Time:* #{Time.zone.now.strftime('%Y-%m-%d %H:%M:%S')}\n"
      message += "*Exception:* `#{exception.message}`\n"

      req = Rack::Request.new(env)
      unless req.params.empty?
        message += "*Parameters:*\n"
        message += req.params.map { |k, v| ">#{k}=#{v}" }.join("\n")
        message += "\n"
      end
      message += "*Backtrace*: \n"
      message += "`#{exception.backtrace.first}`"

      notifier = Slack::Notifier.new slack_options.fetch(:webhook_url),
                                     channel: slack_options.fetch(:channel),
                                     username: slack_options.fetch(:username),
                                     icon_emoji: slack_options.fetch(:icon_emoji),
                                     attachments: [{
                                       color: 'danger',
                                       title: title,
                                       text: message,
                                       mrkdwn_in: %w(text title fallback)
                                     }]
      notifier.ping ''
    end
  end
end
