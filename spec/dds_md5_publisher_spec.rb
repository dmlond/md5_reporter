require_relative '../dds_md5_publisher'
require 'bunny-mock'

describe DdsMd5Publisher do
  let(:mocked_bunny) { BunnyMock.new }
  subject {
    DdsMd5Publisher.new mocked_bunny
  }

  it { is_expected.to respond_to(:publish_file_version_id).with(1).argument }
  it { is_expected.to respond_to(:publish_file_version_ids_from).with(1).argument }

  describe '#publish_file_version_id' do
    let(:id_to_publish) { 'id-to-publish' }
    let(:task_queue) {
      subject.channel.queue(ENV['TASK_QUEUE_NAME'], durable: true)
    }

    it 'should publish the id to the task queue' do
      expect(task_queue).to be
      # the bunny-mock default exchange is a standard BunnyMock::Exchange::Direct
      # so a BunnyMock::Queue has to be manually bound to that exchange
      # before running the test
      task_queue.bind subject.exchange, routing_key: task_queue.name
      subject.publish_file_version_id id_to_publish
      expect(task_queue.message_count).to eq(1)
      payload = task_queue.all.first
      expect(payload[:message]).to eq(id_to_publish)
    end
  end

  describe '#publish_file_version_ids_from' do
    let(:ids) { [
        'id-1',
        'id-2'
    ] }
    let(:io_to_publish) {
      io = StringIO.new("")
      ids.each do |id|
        io.puts id
      end
      io.rewind
      io
    }

    before do
      ids.each do |id|
        is_expected.to receive(:publish_file_version_id)
          .with(id)
      end
    end
    it 'should publish all ids' do
      subject.publish_file_version_ids_from io_to_publish
    end
  end
end
