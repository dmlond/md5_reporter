#!/usr/local/bin/ruby
require 'sneakers'
require 'sneakers/runner'
require 'sneakers/handlers/maxretry'
require 'logger'

class DdsMd5Subscriber
  require_relative 'dds_md5_reporter'
  include Sneakers::Worker
  from_queue ENV['TASK_QUEUE_NAME'],
      :ack => true,
      :durable => true,
      :arguments => {
      'x-dead-letter-exchange' => "#{ENV['TASK_QUEUE_NAME']}-retry"
    }

  def work(file_version_id)
    logger.info("processing file_version_id: #{file_version_id}")
    has_error = false
    begin
      DdsMd5Reporter.new(
        file_version_id: file_version_id,
        user_key: ENV['USER_KEY'],
        agent_key: ENV['AGENT_KEY'],
        dds_api_url: ENV['DDS_API_URL']
      ).report_md5
      logger.info("md5 reported!")
    rescue StandardError => e
      logger.error(e.message)
      has_error = true
    rescue ArgumentError => e
      logger.error(e.message)
      has_error = true
    rescue
      logger.error(e.message)
      has_error = true
    end
    if has_error
      reject!
    else
      ack!
    end
  end

  protected

end

if $0 == __FILE__
  Sneakers.configure(
    :amqp => ENV['AMQP_URL'],
    :daemonize => false,
    :log => STDOUT,
    :handler => Sneakers::Handlers::Maxretry,
    :workers => 1,
    :threads => 1,
    :prefetch => 1,
    :exchange => 'sneakers',
    :exchange_options => { :type => 'topic', durable: true },
    :routing_key => ['#', 'something']
  )
  Sneakers.logger.level = Logger::INFO

  r = Sneakers::Runner.new([ DdsMd5Subscriber ])
  r.run
end
