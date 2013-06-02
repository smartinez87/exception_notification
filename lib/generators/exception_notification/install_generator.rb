module ExceptionNotification
  module Generators
    class InstallGenerator < Rails::Generators::Base
      desc "Creates a ExceptionNotification initializer."

      source_root File.expand_path('../templates', __FILE__)
      class_option :resque, :type => :boolean, :desc => 'Add support for sending notifications when errors occur in Resque jobs.'
      class_option :sidekiq, :type => :boolean, :desc => 'Add support for sending notifications when errors occur in Sidekiq jobs.'

      def copy_initializer
        template 'exception_notification.rb', 'config/initializers/exception_notification.rb'
      end
    end
  end
end
