# Simple tracking of custom events


Library to store custom data in lists by days in Redis.
Old data is automatically removed.
Useful for debugging and tracking different events in application.


## Overview
Data is stored in Redis in lists with names:
_SITE_NAME_ : lists : _list_name_ : _day_ - Redis list

for example,

    mysite:lists:mylist:20130407 - list for day April 04, 2013


## Installation

It uses gem 'redis' and relies on $redis global variable to access Redis server.

Gemfile:

    gem 'redis'
    gem 'simple_events_redis'



Setup:

initializer:

```ruby

# config/initializers/simple_events_redis.rb

require 'events'

$Mylog = SimpleEventsRedis::Events

$Mylog.this_site_name='sitename'
$Mylog.set_config({:EXPIRE_DAYS => 7})
```


## Add new item to list

```ruby
$Mylog.add('debug', {:msg=>'hello. something happened'})
```



