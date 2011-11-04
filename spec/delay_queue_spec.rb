require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "DelayQueue" do
  before(:each) do
    redis = Redis.new(:host => '127.0.0.1', :port => '6379')
    @queue = DelayQueue.new(redis, 'test_delay_queue')
  end

  after(:each) do
    @queue.delete_all!
  end

  describe "#enqueue" do
    it "should enable the specification of a time before which the item may not be dequeued" do
      @queue.enqueue('a', :until => Time.now + 2)
      sleep 1
      @queue.dequeue.should be_nil
      sleep 2
      @queue.dequeue.should == 'a'
    end

    it "should enable the specification of a delay to wait before releasing the item from the queue" do
      @queue.enqueue('a', :delay => 2)
      sleep 1
      @queue.dequeue.should be_nil
      sleep 2
      @queue.dequeue.should == 'a'
    end

    context "when no options are provided" do
      it "should not delay the item from being dequeued" do
        @queue.enqueue('a')
        @queue.dequeue.should == 'a'
      end
    end
    
    context "enqueing an item more than once" do
      it "should not add the item a second time" do
        @queue.enqueue('a')
        @queue.enqueue('a', :delay => 60)
        @queue.size.should == 1
      end

      it "should update the time at which to enable the item to be dequeued" do
        @queue.enqueue('a')
        @queue.enqueue('a', :delay => 60)
        @queue.should_not be_empty
        @queue.dequeue.should be_nil

        @queue.delete_all!

        @queue.enqueue('a', :delay => 60)
        @queue.enqueue('a')
        @queue.dequeue.should == 'a'
      end
    end
  end

  describe "#delete_all!" do
    it "should remove all elements from the queue, whether or not they are ready to be dequeued" do
      @queue.enqueue('test')
      @queue.should_not be_empty
      @queue.delete_all!
      @queue.should be_empty
    end
  end

  describe "#acquire_lock" do
    after(:each) do
      @queue.release_lock
    end

    context "when the lock is not already taken" do
      it "should return true" do
        @queue.acquire_lock.should be_true
      end

      it "should lock the resource" do
        @queue.acquire_lock
        @queue.acquire_lock.should be_false
      end
    end

    context "when the lock is already taken" do
      it "should return false" do
        @queue.acquire_lock
        @queue.acquire_lock.should be_false
      end
    end
  end

  describe "#break_lock" do
    after(:each) do
      @queue.release_lock
    end

    context "when the lock is not already taken" do
      it "should be true" do
        @queue.break_lock.should be_true
      end

      it "should lock the resource" do
        @queue.break_lock
        @queue.acquire_lock.should be_false
      end
    end

    context "when the lock is taken and not yet expired" do
      it "should be false" do
        @queue.acquire_lock
        @queue.break_lock.should be_false
      end
    end

    context "when the lock is taken, but expired" do
      it "should be true" do
        @queue.acquire_lock
        sleep(3)
        @queue.break_lock.should be_true
      end

      it "should lock the resource" do
        @queue.acquire_lock
        sleep(3)
        @queue.break_lock
        @queue.acquire_lock.should be_false
      end
    end

    it "should be able to break an expired lock acquired through breaking a lock" do
      @queue.break_lock
      sleep(3)
      @queue.break_lock.should be_true
    end
  end

  describe "#dequeue" do
    context "when the queue is empty" do
      it "should return nil" do
        @queue.dequeue.should be_nil
      end
    end

    context "when the queue has an element that is not ready to be dequeued" do
      it "should return nil" do
        @queue.enqueue('a', :delay => 2)
        @queue.dequeue.should be_nil
      end
    end

    context "when the queue has an element that is ready to be dequeued" do
      it "should return that element" do
        @queue.enqueue('a', :delay => 0)
        @queue.dequeue.should == 'a'
      end

      it "should remove that element from the queue" do
        @queue.enqueue('a', :delay => 0)
        @queue.dequeue.should == 'a'
        @queue.should be_empty
      end
    end
  end

  describe "#size" do
    context "when the queue is empty" do
      it "should be 0" do
        @queue.size.should == 0
      end
    end

    context "when the queue has N elements, regardless of whether or not they are ready to be dequeued" do
      it "should match the number of elements" do
        @queue.enqueue('a')
        @queue.size.should == 1

        @queue.enqueue('b', :delay => 60)
        @queue.size.should == 2

        @queue.enqueue('c')
        @queue.size.should == 3
      end
    end
  end

  describe "#empty?" do
    context "when the queue is empty" do
      it "should be true" do
        @queue.should be_empty
      end
    end

    context "when the queue has an element that is not ready to be dequeued" do
      it "should be false" do
        @queue.enqueue('a', :delay => 0)
        @queue.should_not be_empty
      end
    end

    context "when the queue has an element that is ready to be dequeued" do
      it "should be false" do
        @queue.enqueue('a', :delay => 0)
        @queue.should_not be_empty
      end
    end
  end
end
