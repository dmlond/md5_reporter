require_relative '../dds_md5_subscriber'
require 'bunny-mock'

describe DdsMd5Subscriber do
  let(:file_version_id) { 'FILE_VERSION_ID' }

  it { expect(described_class).to include(Sneakers::Worker) }
  it { expect(ENV['TASK_QUEUE_NAME']).not_to be_nil }
  it { expect(subject.queue.name).to eq(ENV['TASK_QUEUE_NAME']) }
  it { is_expected.to respond_to(:work) }

  describe '#work' do
    let(:mock_reporter) { instance_double('DdsMd5Reporter') }
    let(:method) { subject.work(file_version_id) }

    before do
      Sneakers.configure(connection: BunnyMock.new)
      expect(DdsMd5Reporter).to receive(:new)
        .with(
          file_version_id: file_version_id,
          user_key: ENV['USER_KEY'],
          agent_key: ENV['AGENT_KEY'],
          dds_api_url: ENV['DDS_API_URL']
        ).and_return(mock_reporter)
      expect(mock_reporter).to receive(:report_md5) { report_md5_response}
    end

    context 'successful report' do
      let(:expected_acknowledgement) { subject.ack! }
      let(:report_md5_response) { true }
      it {
        expect(expected_acknowledgement).not_to be_nil
        expect(method).to eq expected_acknowledgement
      }
    end

    context 'reporter exception thrown' do
      let(:expected_error) { StandardError.new("failed dds api request") }
      let(:expected_acknowledgement) { subject.reject! }
      let(:report_md5_response) { raise(expected_error) }
      it {
        expect(expected_acknowledgement).not_to be_nil
        expect(method).to eq expected_acknowledgement
      }
    end
  end
end
