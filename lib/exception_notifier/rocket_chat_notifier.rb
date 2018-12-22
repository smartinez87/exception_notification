module ExceptionNotifier
  class RocketChatNotifier < SlackNotifier
    def initialize(options)
      super

      return unless options.key?(:webhook_url)

      @notifier = RocketChat::Notifier.new(options.fetch(:webhook_url), options)
    end
  end
end
