require 'events'


describe 'Events - Stats' do
  before(:all) do
    @lib = SimpleEventsRedis::Events

    @lib.this_site_name = 'testsite'

    @lib.clear_stats_all

  end


  after(:all) do
    @lib.clear_stats_all

  end


  context 'Stats - general' do
    it "has add method" do
      @lib.stat_add('counter1').should be true
    end

    it "add" do
      @lib.clear_stats_all

      expect{
        @lib.stat_add("counter1")
      }.to change{
        @lib.redis.hget(@lib.redis_key_stat, "counter1").to_i
      }.by(1)

    end

    it "add with amount" do
      @lib.clear_stats_all

      n = 5
      expect{
        @lib.stat_add("counter1", n)
      }.to change{
        @lib.redis.hget(@lib.redis_key_stat, "counter1").to_i
      }.by(n)

    end


    it "add several times" do
      name = 'counter1'

      @lib.clear_stats_all

      expect{
        @lib.stat_add(name, 7)
        @lib.stat_add(name, 5)

      }.to change{
        @lib.get_stat(name, 0).to_i
      }.by(12)

    end


    it "get stats" do
      @lib.clear_stats_all

      #
      name = 'counter1'

      @lib.stat_add(name, 3)
      @lib.stat_add(name, 5)

      rows = @lib.get_stats

      rows.count.should == 1

    end

    it "get stats - content" do
      @lib.clear_stats_all

      #
      counters = ['c1', 'c2', 'c3']
      n1 = 5
      n2 = 7


      counters.each do |name|
        @lib.stat_add(name, n1)
        @lib.stat_add(name, n2)
      end

      rows = @lib.get_stats

      rows.each do |row|
        counters.should include (row[:event])
        row[:amount].should == n1+n2
      end

    end

  end


  context 'Stats - performance' do
    it "has add method" do
      @lib.stat_add_perf('counter1', 10).should be true
    end

    it "add" do
      @lib.clear_stats_all

      old_time = (@lib.redis.hget(@lib.redis_key_stat, "counter1_time") || 0).to_i
      old_n = (@lib.redis.hget(@lib.redis_key_stat, "counter1_n") || 0).to_i

      @lib.stat_add_perf("counter1", 15)

      (@lib.redis.hget(@lib.redis_key_stat, "counter1_n").to_i - old_n).should == 1
      (@lib.redis.hget(@lib.redis_key_stat, "counter1_time").to_i - old_time).should == 15

    end

    it "measure perf" do
      @lib.clear_stats_all

      @lib.stat_perf_measure('myevent') do
        sleep 4
      end

      (@lib.redis.hget(@lib.redis_key_stat, "myevent_n").to_i).should == 1
      (@lib.redis.hget(@lib.redis_key_stat, "myevent_time").to_i).should > 3000

    end
  end


  context 'Expiration' do
    it "should expire" do
      name = 'e1'

      @lib.clear_stats_all

      #
      @lib.stat_add(name, 1)

      ( @lib.redis.ttl @lib.redis_key_stat() ).should > 0

    end
  end



end