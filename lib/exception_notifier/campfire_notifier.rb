class ExceptionNotifier
  class CampfireNotifier
    cattr_accessor :tinder_available do true end

    attr_accessor :subdomain
    attr_accessor :token
    attr_accessor :room

    def initialize(options)
      begin
        return unless tinder_available

        subdomain = options.delete(:subdomain)
        room_name = options.delete(:room_name)
        @campfire = Tinder::Campfire.new subdomain, options
        @room     = @campfire.find_room_by_name room_name
      rescue
        @campfire = @room = nil
      end
    end

    def exception_notification(exception)
      @room.paste "A new exception occurred: '#{exception.message}' on '#{exception.backtrace.first}'" if active?
    end

    private

    def active?
      !@room.nil?
    end
  end
end

ExceptionNotifier::CampfireNotifier.tinder_available = Gem.loaded_specs.keys.include? 'tinder'
