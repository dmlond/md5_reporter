#!/usr/local/bin/ruby

class DdsMd5Publisher
  require "bunny"

  attr_accessor :connection, :channel, :exchange
  def initialize(connection=nil)
    if connection
      @connection = connection
    end
    connect
  end

  def publish_file_version_id(id)
    @exchange.publish(id, routing_key: ENV['TASK_QUEUE_NAME'])
  end

  def publish_file_version_ids_from(io)
    while (id = io.gets)
      publish_file_version_id(id.chomp)
    end
  end

  private
  def connect
    unless @connection
      @connection = Bunny.new(ENV['AMQP_URL'], automatically_recover: false)
    end
    @connection.start
    @channel = @connection.create_channel
    @exchange = @channel.default_exchange
  end
end

def usage
  $stderr.puts "usage: dds_md5_publisher <path_to_file_with_ids_one_per_line>
  requires the following Environment Variables
    AMQP_URL: full url to amqp service
    TASK_QUEUE_NAME: name of queue used by the dds_md5_subscriber.rb script
  "
  exit(1)
end

if $0 == __FILE__
  input_file = ARGV.shift or die usage
  die usage unless(ENV['AMQP_URL'] && ENV['TASK_QUEUE_NAME'])
  File.open(input_file, 'r') do |id_file|
    DdsMd5Publisher.new.publish_file_version_ids_from id_file
  end
  $stderr.puts "all published"
end
