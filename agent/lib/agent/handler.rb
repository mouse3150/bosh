
module Bosh::Agent

  class MessageHandlerError < StandardError; end
  class UnknownMessage < StandardError; end

  class Handler
    attr_reader :processors

    class << self
      def start
        Handler.new.start
      end
    end

    def initialize
      redis_config = Config.redis_options
      @pubsub_redis = Redis.new(redis_config)
      @redis = Redis.new(redis_config)
      @agent_id = Config.agent_id
      @logger = Config.logger

      @lock = Mutex.new
      @long_running_agent_task = []
      @results = []
      message_processors
    end

    # TODO: add runtime loading of messag handlers
    def message_processors
      message_consts = Bosh::Agent::Message.constants
      @processors = {}
      message_consts.each do |c|
        klazz = Bosh::Agent::Message.const_get(c)
        if klazz.respond_to?(:process)
          @processors[c.downcase] = klazz
        end
      end
    end

    def start
      # FIXME: terminate gracefully by unsubscribing before exit
      # TODO: deal with signals
      trap("TERM") { "Shutting down agent" ; exit }

      subscription = "rpc:agent:#{@agent_id}"

      @pubsub_redis.subscribe(subscription) do |on|
        on.subscribe do |sub, msg|
          @logger.info("Subscribed to #{subscription}")
        end
        on.message do |sub, raw_msg|
          msg = Yajl::Parser.new.parse(raw_msg)

          message_id = msg['message_id']
          method = msg['method']
          args = msg['arugments']

          if method == "get_task"
            handle_get_task(message_id, args)
          end

          processor = lookup(method)
          if processor
            Thread.new {
              if processor.respond_to?(:long_running?)
                if @long_running_agent_task.emtpy?
                  process_long_running(message_id, processor, args)
                else
                  payload = {:excpetion => "already running long running task"}
                  publish(message_id, payload)
                end
              else
                payload = process(processor, args)
                publish(message_id, payload)
              end
            }
          end
        end
        on.unsubscribe do |sub, msg|
          puts "unsubscribing"
        end
      end
    end

    # TODO:
    def lookup(method)
      @processors[method]
    end

    def generate_agent_task_id
      UUIDTools::UUID.random_create.to_s
    end

    def handle_get_task(message_id, args)
      agent_task_id = args["agent_task_id"]

      if @long_running_agent_task == agent_task_id
        publish(message_id, {"state" => "running"})
      else
        rs = @results.find { |time, task_id, result| task_id == agent_task_id }
        if rs
          time, task_id, result = rs
          publish(message_id, result)
        else
          # FIXME: figure out exception strategy - currently the director wouldn't
          # deal with the exceptions raises if 
        end
      end
    end

    def publish(message_id, payload)
      @redis.publish(message_id, Yajl::Encoder.encode(payload))
    end

    def process_long_running(message_id, processor, args)
      agent_task_id = generate_agent_task_id

      @lock.synchronize do
        @long_running_agent_task = [agent_task_id]
      end

      payload = {:value => {:agent_task_id => agent_task_id}}
      publish(message_id, payload)

      result = process(processor, args)

      @lock.synchronize do 
        @results << [Time.now.to_i, agent_task_id, result]
        @long_running_agent_task = []
      end
    end

    def process(processor, args)
      begin
        result = processor.process(args)
        return {:value => result}
      rescue Bosh::Agent::MessageHandlerError => e
        return {:exception => e.inspect}
      end
    end

  end

  # Built-in message handlers
  module Message
    class Ping
      def self.process(args)
        "pong"
      end
    end

    class Noop
      def self.process(args)
        "nope"
      end
    end
  end

end