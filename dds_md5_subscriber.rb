#!/usr/local/bin/ruby
require 'sneakers'
require 'sneakers/runner'
require 'logger'

class DdsMd5Subscriber
  require_relative 'dds_md5_reporter'
  include Sneakers::Worker
  from_queue ENV['TASK_QUEUE_NAME'],
      :prefetch => 1,
      :threads => 1,
      :ack => true,
      :durable => true

  def work(file_version_id)
    logger.info("processing file_version_id: #{file_version_id}")
    DdsMd5Reporter.new(
      file_version_id: file_version_id,
      user_key: ENV['USER_KEY'],
      agent_key: ENV['AGENT_KEY'],
      dds_api_url: ENV['DDS_API_URL']
    ).report_md5
    logger.info("md5 reported!")
    ack!
  end

  protected

end

if $0 == __FILE__
  Sneakers.configure(
    :amqp => ENV['AMQP_URL'],
    :daemonize => false,
    :log => STDOUT,
    :workers => 1
  )
  Sneakers.logger.level = Logger::INFO

  r = Sneakers::Runner.new([ DdsMd5Subscriber ])
  r.run
end
