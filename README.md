DelayQueue
==========

DelayQueue provides a thread safe, Redis backed queue with two simple properties:

1. items may be queued with a delay so that they can't be dequeued until some time in the future
2. each item in the queue is unique


Use Cases
=========

Throttling
----------

For example, if you want to send notifications to users when something happens, but you don't want users to be flooded with notifications (eg: bug report emails), you could put a user id into a 'bug_notifications' queue every time a bug occurs, setting the dequeue time to @user.last_notified_at + MAX_NOTIFY_FREQUENCY. The uniqueness constraint ensures that the user only gets added once until it is next dequeued, while the time constraint ensures that the user id will only be dequeued once per MAX_NOTIFY_FREQUENCY.

External Resources
------------------

If you are communicating with an external resource, and that resource is down, you will want to re-queue the job, but you don't want to hit the resource right away. Maybe wait a minute before trying again. If the resource is still down, wait longer. This prevents your system from getting caught up processing jobs that can't complete and is also considerate of the external resource that may be choking under heavy load and won't benefit from a worker continually trying to hit the resource again.



Usage
=====

In your Gemfile:

    gem 'delay_queue'

Example:

    $ irb
    require 'redis'
    require 'delay_queue'
    redis = Redis.new(:host => '127.0.0.1', :port => '6379')
    queue = DelayQueue.new(redis, 'bug_notification_queue')
    queue.enqueue('123')
    queue.dequeue
      - '123'

    queue.enqueue('123', :delay => 3)
    queue.dequeue
      - nil
    sleep 3
    queue.dequeue
      - '123'

    queue.enqueue('123', :until => Time.now + 3)
    queue.dequeue
      - nil
    sleep 3
    queue.dequeue
      - '123'

    queue.enqueue('123')
    queue.enqueue('123')
    queue.dequeue
      - '123'
    queue.dequeue
      - nil

Note that since DelayQueue uses Redis, all items are queued and returned as strings.


Contributing to delay_queue
==========================
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add specs for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.
