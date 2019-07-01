require_relative '../dds_md5_subscriber'
require 'bunny-mock'

describe DdsMd5Subscriber do
  let(:file_version_id) { 'FILE_VERSION_ID' }

  it { expect(described_class).to include(Sneakers::Worker) }
  it { expect(ENV['TASK_QUEUE_NAME']).not_to be_nil }
  it { expect(subject.queue.name).to eq(ENV['TASK_QUEUE_NAME']) }

  describe '#work' do
    let(:mock_reporter) { instance_double('DdsMd5Reporter') }
    it { is_expected.to respond_to(:work) }
    let(:method) { subject.work(file_version_id) }
    let(:ack) { subject.ack! }

    it {
      Sneakers.configure(connection: BunnyMock.new)
      expect(DdsMd5Reporter).to receive(:new)
        .with(
          file_version_id: file_version_id,
          user_key: ENV['USER_KEY'],
          agent_key: ENV['AGENT_KEY'],
          dds_api_url: ENV['DDS_API_URL']
        ).and_return(mock_reporter)
      expect(mock_reporter).to receive(:report_md5)

      expect(ack).not_to be_nil
      expect(method).to eq ack
    }
  end
end
