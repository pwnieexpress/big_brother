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