module SimpleEventsRedis

  require 'redis'

  class Events
    @@redis = nil

    # static data

    @@SITE_NAME = '' # default site

    # config
    @@config = {:EXPIRE_DAYS=>3}


    def self.this_site_name
      return @@SITE_NAME
      #return (Rails.application.config.SITE_NAME rescue '')
    end

    def self.this_site_name=(v)
      @@SITE_NAME = v
    end

    def self.config(iv)
      return @@config[iv]
    end

    def self.set_config(hash)
      hash.each_pair { |k,v| @@config[k] = v }
    end

    # redis object to access Redis server
    def self.redis
      return @@redis unless @redis.nil?

      # init by global object
      unless $redis.nil?
        @@redis = $redis
        return @@redis
      end


      # default
      @@redis = Redis.new(:host => 'localhost', :port => 6379)

      @@redis
    end

    # methods for any log_type add_<<ANY_LOG_TYPE>>
    def self.method_missing(method_name, *args, &block)
      if method_name.to_s =~ /^log_(.+)$/
        self.log($1, *args)
      else
        super
      end
    end


    # logging

    def self.log(log_name, data={})
      t = Time.now.utc.to_i
      rkey = self.redis_key_log log_name

      #
      hash = {:created=>t}
      if data.is_a?(Hash)
        data.each_pair { |k,v| hash["#{k}"] = v }
      elsif data.is_a?(String)
        hash["msg"] = data
      else
        hash["msg"] = "#{data.inspect}"
      end

      #
      require 'json'
      s = JSON.generate(hash)

      redis.rpush rkey, s
      redis.expire rkey, self.config(:EXPIRE_DAYS)*24*60*60

      return true
    end


    def self.log_event(log_name, event_name, msg, data={})
      data['event'] = event_name
      data['msg'] = msg
      return self.log log_name, data
    end

    #
    def self.debug(event_name, msg, data={})
      data['event'] = event_name
      data['msg'] = msg
      return self.log 'debug', data
    end


    def self.get_logs_of_site(site_name, log_name, n_days_back=-1, filter={})
      all_keys = redis.keys(self.redis_key_log_prefix(site_name) + "#{log_name}:" +'*')

      return [] if all_keys.nil?

      require 'json'

      tnow = Time.now.utc.to_i
      rows = []
      all_keys.each do |rkey|
        day = self.parse_date rkey

        # if cannot parse key
        next if day.nil?

        # if not too old day
        if n_days_back>0
          next if tnow - day.to_i > n_days_back * (60*60*24)
        end

        # get all items from the list
        values = redis.lrange rkey, 0, 100000

        values.each do |v|
          #r = Marshal.load v
          r = JSON.parse(v)

          # filter
          is_good = true

          unless filter.nil? && filter.is_a?(Hash)
            filter.each_pair do |field_name, field_value|
              if r[field_name].nil?
                is_good = false
                break
              end
              if r[field_name] != field_value
                is_good = false
                break
              end
            end
          end

          # add to result
          if is_good
            rows << r
          end
        end

      end

      rows
    end


    def self.get_logs(log_name, n_days_back=-1, filter={})
      return get_logs_of_site(self.this_site_name, log_name, n_days_back, filter)
    end



    # status
    def self.status_set(event_name)
      redis.hset self.redis_key_status, event_name, Time.now.utc.to_i

      return true
    end

    def self.get_status_of_site(site_name, event_name, v_def=nil)
      v = redis.hget self.redis_key_status(site_name), event_name
      v ||= v_def
      v
    end

    def self.get_status(event_name, v_def=nil)
      return get_status_of_site(self.this_site_name, event_name, v_def)
    end


    def self.get_statuses_of_site(site_name, pattern='*')
      # event_names like 'name*'

      rows = []

      all_values = redis.hgetall self.redis_key_status(site_name)

      all_values.each do |event, v|
        rows << {:site=>site_name, :event=>event, :v=>v, }
      end

      rows
    end

    def self.get_statuses(pattern='*')
      return get_statuses_of_site(self.this_site_name, pattern)
    end



    # counters

    def self.stat_add(event_name, n=1)
      rkey = self.redis_key_stat
      redis.hincrby rkey, event_name, n
      redis.expire rkey, self.config(:EXPIRE_DAYS)*24*60*60

      return true
    end

    def self.stat_add_perf(event_name, duration, n=1)
      redis.hincrby self.redis_key_stat, event_name+'_time', duration.to_i
      redis.hincrby self.redis_key_stat, event_name+'_n', 1

      return true
    end

    def self.stat_perf_measure(event_name)
      started = Time.now.to_f
      yield
      ended = Time.now.to_f

      duration = (ended - started)*1000.floor.to_i

      self.stat_add_perf event_name, duration
    end


    def self.get_stat_of_site(site_name, event_name, v_def=0)
      v = redis.hget self.redis_key_stat(site_name), event_name
      v ||= v_def
      v
    end

    def self.get_stat(event_name, v_def=0)
      return get_stat_of_site(self.this_site_name, event_name, v_def)
    end


    def self.get_stats_of_site(site_name, n_days_back=1)
      rows = []

      self.stat_walk(site_name, n_days_back, 0) do |key, day|
        all_values = redis.hgetall key

        all_values.each do |event, v|
          #rows << {:site=>site_name, :created=>day.to_i, :date=>Time.at(day.to_i), :event=>event, :amount=>v.to_i}
          rows << {:site=>site_name, :created=>day.to_i, :event=>event, :amount=>v.to_i}
        end
      end

      rows
    end


    def self.get_stats(n_days_back=1)
      return get_stats_of_site(self.this_site_name, n_days_back)
    end

    def self.stat_walk(site_name, n_days_back_from, n_days_back_to)
      tnow = Time.now.utc.to_i

      key_prefix = self.redis_key_stat_prefix(site_name)
      keys = redis.keys key_prefix + "*"

      keys.each do |key|
        # parse key
        mm = key.scan(/#{key_prefix}(\d+)$/i)

        next if mm.nil? || mm[0].nil?

        day = self.parse_date(mm[0][0])

        next if day.nil?

        # too old
        if n_days_back_from>=0
          next if tnow - day.to_i > n_days_back_from * (60*60*24)
        end

        # too fresh
        if n_days_back_to>=0
          next if tnow - day.to_i < n_days_back_to * (60*60*24)
        end

        # do the work
        yield(key, day)

      end
    end





    # helper methods

    def self.key_day(d=nil)
      d ||= DateTime.now.new_offset(0)

      d.strftime("%Y%m%d")
    end

    def self.redis_key_prefix(site_name=nil)
      site_name ||= self.this_site_name

      "#{site_name=='' ? '' : site_name+':'}"
    end


    # redis keys for log
    def self.redis_key_log_prefix(site_name=nil)
      self.redis_key_prefix(site_name) + "log:"
    end

    def self.redis_key_log(name, site_name=nil)
      self.redis_key_log_prefix(site_name) + "#{name}:" + self.key_day
    end


    # redis keys for status

    def self.redis_key_status(site_name=nil)
      self.redis_key_prefix(site_name) + 'status'
    end


    # redis keys for stat

    def self.redis_key_stat_prefix(site_name=nil)
      self.redis_key_prefix(site_name) + 'stat:'
    end

    def self.redis_key_stat(site_name=nil)
      self.redis_key_stat_prefix(site_name) + self.key_day
    end


    #
    def self.parse_date(s)
      # parse key
      mm = s.scan(/(\d\d\d\d)(\d\d)(\d\d)$/i)

      return nil if mm.nil? || mm[0].nil?

      y, m, d = mm[0].map{|v| v.to_i}

      Time.utc(y,m,d)
    end



    # clear data

    def self.clear_logs_all
      keys = redis.keys self.redis_key_log_prefix + '*'
      return if keys.empty?
      redis.del keys
    end

    def self.clear_logs(name)
      keys = redis.keys self.redis_key_log_prefix+"#{name}:*"
      return if keys.empty?
      redis.del keys
    end

    # TODO:
    def self.clear_logs_old(name)

    end


    # clear status

    def self.clear_status_all
      rkey = self.redis_key_status

      redis.del rkey
    end



    # clear stats

    def self.clear_stats_all
      keys = redis.keys self.redis_key_stat_prefix+"*"
      return if keys.empty?
      redis.del keys
    end


    # clear data older than n_days_back
    def self.clear_stats_old(n_days_back=1)
      rows = []

      # all days older than N days
      self.stat_walk(-1, n_days_back) do |key, day|
        redis.del key
      end

      rows
    end



  end


end

