### Amazon SNS Notifier

Notify all exceptions Amazon - Simple Notification Service: [SNS](https://aws.amazon.com/sns/).

#### Usage

Add the [aws-sdk-sns](https://github.com/aws/aws-sdk-ruby/tree/master/gems/aws-sdk-sns) gem to your `Gemfile`:

```ruby
  gem 'aws-sdk-sns', '~> 1.5'
```

To configure it, you **need** to set 3 required options for aws: `region`, `access_key_id` and `secret_access_key`, and one more option for sns: `topic_arn`.

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        sns: {
                                          region: 'us-east-x',
                                          access_key_id: 'access_key_id',
                                          secret_access_key: 'secret_access_key',
                                          topic_arn: 'arn:aws:sns:us-east-x:XXXX:my-topic'
                                        }
```

##### sns_prefix
*String, optional *

Prefix in the notification subject, by default: "[Error]"

##### backtrace_lines
*Integer, optional *

Number of backtrace lines to be displayed in the notification message. By default: 10

#### Note:
* You may need to update your previous `aws-sdk-*` gems in order to setup `aws-sdk-sns` correctly.
* If you need any further information about the available regions or any other SNS related topic consider: [SNS faqs](https://aws.amazon.com/sns/faqs/)
