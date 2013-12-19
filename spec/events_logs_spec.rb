require 'events'


describe 'Events - Logging' do
  before(:all) do
    @lib = SimpleEventsRedis::Events

    @lib.this_site_name = 'testsite'

    @lib.clear_logs_all

  end


  after(:all) do
    @lib.clear_logs_all

  end


  context 'logs-general' do
    it "has add method" do
      @lib.log('mylog', 'event1').should be true
    end

    it "has other custom methods" do
      @lib.log_mycustom('event1').should be true
    end

    it "has log_event" do
      expect{
        @lib.log_event('mylog', 'registration', 'submit')
      }.to change{
        @lib.redis.llen(@lib.redis_key_log("mylog"))
      }.by(1)
    end

    it "accept hash" do
      expect{
        @lib.log('mylog', {:user_id=>123, :product_name=>'big cat'})
      }.to change{
        @lib.redis.llen(@lib.redis_key_log("mylog"))
      }.by(1)
    end



    it "add new item to Redis list" do
      @lib.clear_logs 'debug'

      expect{
        @lib.log('debug', 'test1')

      }.to change{
        @lib.redis.llen(@lib.redis_key_log("debug"))
      }.by(1)
    end


    it "add to the correct list" do
      @lib.clear_logs 'debug'
      @lib.clear_logs 'list2'

      expect{
        @lib.log('debug', {:user_id=>123, :product_name=>'big cat'})
        @lib.log('debug', {:user_id=>456, :product_name=>'big cat'})
        @lib.log('list2', {:membership=>'premium'})
        @lib.log('debug', {:user_id=>456, :product_name=>'big cat'})

      }.to change{
        @lib.redis.llen(@lib.redis_key_log("debug"))
      }.by(3)
    end


    it "clear list" do
      @lib.clear_logs 'debug'

      expect{
        @lib.log('debug', {:user_id=>123, :product_name=>'big cat'})
        @lib.log('debug', 'just text')

        @lib.clear_logs 'debug'
      }.to change{
        @lib.redis.llen(@lib.redis_key_log("debug"))
      }.by(0)

    end


    it "clear correct list" do
      @lib.clear_logs 'debug'
      @lib.clear_logs 'list2'

      expect{

        @lib.log('list2', {:car_name=>'Mercedes'})

        @lib.log('debug', 'some text')
        @lib.log('debug', {:user_id=>456, :product_name=>'big cat'})

        @lib.log('list2', {:car_name=>'VW'})

        @lib.log('debug', {:user_id=>456, :product_name=>'big cat'})

        @lib.clear_logs 'debug'
      }.to change{
        @lib.redis.llen(@lib.redis_key_log("list2"))
      }.by(2)

    end


    it "get logs" do
      name = 'mylist'

      @lib.clear_logs name

      expect{
        @lib.log(name, "sample msg")
        @lib.log(name, {:car_name=>'Mercedes'})
      }.to change{
        @lib.get_logs(name).count
      }.by(2)

    end

    it "get logs - content" do
      name = 'mylist'
      msg_list = ['msg1', 'second', 'third']

      @lib.clear_logs name

      msg_list.each do |msg|
        @lib.log(name, msg)
      end

      rows = @lib.get_logs(name)

      rows.each do |row|
        msg_list.should include (row['msg'])
      end

    end

    it "get logs - filter - old" do

    end


    it "get logs - filter - custom" do
      name = 'mylog'

      @lib.clear_logs name

      #
      @lib.log(name, {'referrer'=>'google', 'user_id'=>10})
      @lib.log(name, {'referrer'=>'bing', 'user_id'=>15})
      @lib.log(name, {'referrer'=>'google', 'user_id'=>10})
      @lib.log(name, {'referrer'=>'wordpress', 'user_id'=>43})
      @lib.log(name, {'user_id'=>99})


      rows = @lib.get_logs(name, 1, {'referrer'=>'google'})

      rows.count.should be 2

      rows.each do |row|
        row['referrer'].should == 'google'
      end


    end
    it "get logs - filter - with keys" do
      name = 'mylog'

      @lib.clear_logs name

      #
      @lib.log(name, {'referrer'=>'google', :user_id=>10})
      @lib.log(name, {'referrer'=>'bing', :user_id=>15})
      @lib.log(name, {'referrer'=>'msn', 'user_id'=>10})
      @lib.log(name, {'referrer'=>'wordpress', 'user_id'=>43})
      @lib.log(name, {'user_id'=>99})


      rows = @lib.get_logs(name, 1, {'user_id'=>10})

      rows.count.should be 2

      rows.each do |row|
        row['user_id'].should == 10
      end


    end


  end



  context "Config" do
    it "should set expire" do
      n = 3

      @lib.set_config(:EXPIRE_DAYS=>n)

      @lib.config(:EXPIRE_DAYS).should == 3
    end
  end


  context 'Expiration' do
    it "should expire" do
      name = 'mylog'

      @lib.clear_logs name

      #
      @lib.log(name, "t1")
      @lib.log(name, "t2")

      (@lib.redis.ttl @lib.redis_key_log(name)).should > 0

    end


    it "should expire in N days" do
      name = 'mylog'

      @lib.clear_logs name

      @lib.set_config(:EXPIRE_DAYS=>2)

      #
      @lib.log(name, "t1")
      @lib.log(name, "t2")

      (@lib.redis.ttl @lib.redis_key_log(name)).should <= 24*60*60*@lib.config(:EXPIRE_DAYS)

    end

  end

end