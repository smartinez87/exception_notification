# frozen_string_literal: true

require 'action_dispatch'
require 'active_support/core_ext/time'
require 'json'

module ExceptionNotifier
  class TeamsNotifier < BaseNotifier
    include ExceptionNotifier::BacktraceCleaner

    class MissingController
      def method_missing(*args, &block); end
    end

    attr_accessor :httparty

    def initialize(options = {})
      super
      @default_options = options
      @httparty = HTTParty
    end

    def call(exception, options = {})
      @options = options.merge(@default_options)
      @exception = exception
      @backtrace = exception.backtrace ? clean_backtrace(exception) : nil

      @env = @options.delete(:env)

      @application_name = @options.delete(:app_name) || rails_app_name
      @gitlab_url = @options.delete(:git_url)
      @jira_url = @options.delete(:jira_url)

      @webhook_url = @options.delete(:webhook_url)
      raise ArgumentError, "You must provide 'webhook_url' parameter." unless @webhook_url

      if @env.nil?
        @controller = @request_items = nil
      else
        @controller = @env['action_controller.instance'] || MissingController.new
        @additional_exception_data = @env['exception_notifier.exception_data']
        request = ActionDispatch::Request.new(@env)

        @request_items = { url: request.original_url,
                           http_method: request.method,
                           ip_address: request.remote_ip,
                           parameters: request.filtered_parameters,
                           timestamp: Time.current }

      end

      payload = message_text

      @options[:body] = payload.to_json
      @options[:headers] ||= {}
      @options[:headers]['Content-Type'] = 'application/json'
      @options[:debug_output] = $stdout

      @httparty.post(@webhook_url, @options)
    end

    private

    def message_text
      text = {
        '@type' => 'MessageCard',
        '@context' => 'http://schema.org/extensions',
        'summary' => "#{@application_name} Exception Alert",
        'title' => "⚠️ Exception Occurred in #{env_name} ⚠️",
        'sections' => [
          {
            'activityTitle' => activity_title,
            'activitySubtitle' => @exception.message.to_s
          }
        ],
        'potentialAction' => []
      }

      text['sections'].push details
      text['potentialAction'].push gitlab_view_link unless @gitlab_url.nil?
      text['potentialAction'].push gitlab_issue_link unless @gitlab_url.nil?
      text['potentialAction'].push jira_issue_link unless @jira_url.nil?

      text
    end

    def details
      details = {
        'title' => 'Details',
        'facts' => []
      }

      details['facts'].push message_request unless @request_items.nil?
      details['facts'].push message_backtrace unless @backtrace.nil?
      details['facts'].push additional_exception_data unless @additional_exception_data.nil?
      details
    end

    def activity_title
      errors_count = @options[:accumulated_errors_count].to_i

      "#{errors_count > 1 ? errors_count : 'A'} *#{@exception.class}* occurred" +
        (@controller ? " in *#{controller_and_method}*." : '.')
    end

    def message_request
      {
        'name' => 'Request',
        'value' => "#{hash_presentation(@request_items)}\n  "
      }
    end

    def message_backtrace(size = 3)
      text = []
      size = @backtrace.size < size ? @backtrace.size : size
      text << '```'
      size.times { |i| text << '* ' + @backtrace[i] }
      text << '```'

      {
        'name' => 'Backtrace',
        'value' => text.join("  \n").to_s
      }
    end

    def additional_exception_data
      {
        'name' => 'Data',
        'value' => "`#{@additional_exception_data}`\n  "
      }
    end

    def gitlab_view_link
      {
        '@type' => 'ViewAction',
        'name' => "\u{1F98A} View in GitLab",
        'target' => [
          "#{@gitlab_url}/#{@application_name}"
        ]
      }
    end

    def gitlab_issue_link
      link = [@gitlab_url, @application_name, 'issues', 'new'].join('/')
      params = {
        'issue[title]' => ['[BUG] Error 500 :',
                           controller_and_method,
                           "(#{@exception.class})",
                           @exception.message].compact.join(' ')
      }.to_query

      {
        '@type' => 'ViewAction',
        'name' => "\u{1F98A} Create Issue in GitLab",
        'target' => [
          "#{link}/?#{params}"
        ]
      }
    end

    def jira_issue_link
      {
        '@type' => 'ViewAction',
        'name' => '🐞 Create Issue in Jira',
        'target' => [
          "#{@jira_url}/secure/CreateIssue!default.jspa"
        ]
      }
    end

    def controller_and_method
      if @controller
        "#{@controller.controller_name}##{@controller.action_name}"
      else
        ''
      end
    end

    def hash_presentation(hash)
      text = []

      hash.each do |key, value|
        text << "* **#{key}** : `#{value}`"
      end

      text.join("  \n")
    end

    def rails_app_name
      return unless defined?(Rails) && Rails.respond_to?(:application)

      if ::Gem::Version.new(Rails.version) >= ::Gem::Version.new('6.0')
        Rails.application.class.module_parent_name.underscore
      else
        Rails.application.class.parent_name.underscore
      end
    end

    def env_name
      Rails.env if defined?(Rails) && Rails.respond_to?(:env)
    end
  end
end
