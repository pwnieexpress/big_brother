# big_brother

An application monitor for Pulse applications.

### Installation ###
    # Add to your Gemfile
    gem 'big_brother', :git => "https://github.com/pwnieexpress/big_brother.git", :tag => 'v1.0.0'

### Usage ###

```ruby
require "big_brother"
BigBrother.start_watching
```

### Configuration ###
By default, the application monitor data will be logged as datadog tags on the `pulse.application.monitor` metric once
every five minutes. This can be configured via environment variables (but probably shouldn't be; we want consistency):

```ruby
ENV['PULSE_APPLICATION_MONITOR_METRIC']   # Name of the datadog metric to use. Defaults to 'pulse.application.monitor'
ENV['BIG_BROTHER_WATCH_INTERVAL']         # Duration (in seconds) to wait between each metric publish. Defaults to 5 minutes.
ENV['STATSD_ADDR']                        # StatsD server address. Defaults to '127.0.0.1:8125'.
```