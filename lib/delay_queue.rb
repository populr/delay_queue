class DelayQueue

  def initialize(redis, queue_name)
    @redis = redis
    @queue_name = queue_name
    @lock_name = 'lock.' + @queue_name
  end

  def include?(item)
    @redis.zscore(@queue_name, item)
  end

  def delete(item)
    @redis.zrem(@queue_name, item)
  end

  def delete_all!
    @redis.del(@queue_name)
  end

  def empty?
    size == 0
  end

  def size
    @redis.zcard(@queue_name)
  end

  # Enqueue a unique item with an optional delay
  #
  # <tt>:item</tt>:: A string
  # <tt>:options</tt>:: An optional hash of one of the following options
  #   <tt>:until</tt>:: Time before which not to allow this item to be dequeued
  #   <tt>:delay</tt>:: Number of seconds to wait before allowing this to be dequeued
  #
  def enqueue(item, options={ :delay => 0})
    if options[:delay]
      time = Time.now + options[:delay]
    elsif options[:until]
      time = options[:until]
    end
    @redis.zadd(@queue_name, time.to_i, item)
  end

  def dequeue
    if acquire_lock || break_lock
      array = @redis.zrangebyscore(@queue_name, 0, Time.now.to_i, :limit => [0, 1])
      item = array.first if array
      @redis.zrem(@queue_name, item) if item
      release_lock
      item
    else # couldn't acquire or break the lock. wait and try again
      # a small sleep value is actually faster than no sleep value, presumably because no
      # delay puts too much stress on Redis
      sleep 0.01
      dequeue
    end
  end

  def acquire_lock # :nodoc:
    @redis.setnx(@lock_name, new_lock_expiration)
  end

  def release_lock # :nodoc:
    @redis.del(@lock_name)
  end

  def break_lock # :nodoc:
    previous = @redis.getset(@lock_name, new_lock_expiration)
    previous.nil? || Time.at(previous.to_i) <= Time.now
  end

  private

  LOCK_DURATION = 1

  def new_lock_expiration
    (Time.now + LOCK_DURATION).to_i
  end

end
