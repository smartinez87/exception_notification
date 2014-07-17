module ExceptionNotifier
  class SlackNotifier

    attr_accessor :notifier

    def initialize(options)
      begin
        team = options.fetch(:team)
        token = options.fetch(:token)
        custom_hook = options.fetch(:custom_hook, nil)
        options[:username] ||= 'ExceptionNotifierBot'

        if custom_hook.nil?
          @notifier = Slack::Notifier.new team, token, options
        else
          @notifier = Slack::Notifier.new team, token, custom_hook, options
        end
      rescue
        @notifier = nil
      end
    end

    def call(exception, options={})
      message = "An exception occurred on *#{Rails.application.class.parent_name} (#{Rails.env})*: ```#{exception.message}```"
      @notifier.ping message if valid?
    end

    protected

    def valid?
      !@notifier.nil?
    end
  end
end
