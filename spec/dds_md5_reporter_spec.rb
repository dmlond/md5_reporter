require 'active_support'
require 'active_support/testing/time_helpers'
require_relative '../dds_md5_reporter'

describe DdsMd5Reporter do
  include ActiveSupport::Testing::TimeHelpers

  let(:upload_id) { 'UPLOAD_ID' }
  let(:file_version_id) { 'FILE_VERSION_ID' }
  let(:file_version) {
    {
      "id" => file_version_id,
      "upload" => {
        "id" => upload_id
      }
    }
  }
  let(:user_key) { 'USER_KEY' }
  let(:agent_key) { 'AGENT_KEY' }
  let(:dds_api_url) { 'DDS_API_URL' }
  let(:expected_json_headers) {
    { 'Content-Type' => "application/json", 'Accept' => "application/json" }
  }

  let(:expected_api_token) { "abc123xyz" }
  let(:expected_auth_header) {
    {
      'Authorization' => expected_api_token
    }.merge(expected_json_headers)
  }

  describe 'instantiation' do
    context 'with missing keywords' do
      subject { DdsMd5Reporter.new }
      it 'should raise an error' do
        expect {
          subject
        }.to raise_error ArgumentError, "missing keywords: file_version_id, user_key, agent_key, dds_api_url"
      end
    end

    context 'with nil file_version_id' do
      subject {
        DdsMd5Reporter.new(
          file_version_id: nil,
          user_key: user_key,
          agent_key: agent_key,
          dds_api_url: dds_api_url
        )
      }
      it 'should raise an error' do
        expect {
          subject
        }.to raise_error ArgumentError, "missing file_version_id, file_version_id, user_key, agent_key, and dds_api_url cannot be nil"
      end
    end

    context 'with nil user_key' do
      subject {
        DdsMd5Reporter.new(
          file_version_id: file_version_id,
          user_key: nil,
          agent_key: agent_key,
          dds_api_url: dds_api_url
        )
      }
      it 'should raise an error' do
        expect {
          subject
        }.to raise_error ArgumentError, "missing user_key, file_version_id, user_key, agent_key, and dds_api_url cannot be nil"
      end
    end

    context 'with nil agent_key' do
      subject {
        DdsMd5Reporter.new(
          file_version_id: file_version_id,
          user_key: user_key,
          agent_key: nil,
          dds_api_url: dds_api_url
        )
      }
      it 'should raise an error' do
        expect {
          subject
        }.to raise_error ArgumentError, "missing agent_key, file_version_id, user_key, agent_key, and dds_api_url cannot be nil"
      end
    end

    context 'with nil dds_api_url' do
      subject {
        DdsMd5Reporter.new(
          file_version_id: file_version_id,
          user_key: user_key,
          agent_key: agent_key,
          dds_api_url: nil
        )
      }
      it 'should raise an error' do
        expect {
          subject
        }.to raise_error ArgumentError, "missing dds_api_url, file_version_id, user_key, agent_key, and dds_api_url cannot be nil"
      end
    end

    context 'when all keywords are present' do
      subject {
        DdsMd5Reporter.new(
          file_version_id: file_version_id,
          user_key: user_key,
          agent_key: agent_key,
          dds_api_url: dds_api_url
        )
      }

      it 'should not raise an error' do
        expect {
          subject
        }.not_to raise_error
      end
    end
  end

  describe 'interface' do
    let(:reporter) {
      DdsMd5Reporter.new(
        file_version_id: file_version_id,
        user_key: user_key,
        agent_key: agent_key,
        dds_api_url: dds_api_url
      )
    }
    subject { reporter }

    describe '#raise_dds_api_exception' do
      it { is_expected.to respond_to(:raise_dds_api_exception) }

      describe 'behavior' do
        let(:resp) { double() }
        let(:expected_preamble) { 'error preamble' }

        before do
          expect(resp).to receive(:body)
            .and_return(expected_body)
        end

        context 'with dds error json response' do
          let(:dds_error_report) {
            {
              "error" => "the error",
              "reason" => "the reason",
              "suggestion" => "the suggestion"
            }
          }
          let(:expected_body) {
            dds_error_report.to_json
          }

          before do
            expect(resp).to receive(:parsed_response)
              .and_return(dds_error_report)
          end
          it {
            expect{
              subject.raise_dds_api_exception(expected_preamble, resp)
            }.to raise_error(StandardError, "#{expected_preamble}: #{dds_error_report["reason"]} #{dds_error_report["suggestion"]}")
          }
        end

        context 'with generic http error' do
          let(:expected_body) { 'not a dds error' }
          let(:expected_response) { 'the response' }
          before do
            expect(resp).to receive(:response)
              .and_return(expected_response)
            it {
              expect{
                subject.raise_dds_api_exception(expected_preamble, resp)
              }.to raise_error(StandardError, "#{expected_preamble}: #{expected_response}")
            }
          end
        end
      end
    end

    describe '#json_headers' do
      it { is_expected.to respond_to(:json_headers) }
      it { expect(subject.json_headers).to eq(expected_json_headers) }
    end

    describe '#auth_token' do
      it { is_expected.to respond_to(:auth_token) }

      shared_context 'mocked auth token request' do
        let(:expected_path) { "#{dds_api_url}/software_agents/api_token" }
        let(:expected_body) {
          {
            agent_key: agent_key,
            user_key: user_key
          }.to_json
        }
        let(:expected_response) {
          instance_double("HTTParty::Response")
        }
        let(:expected_response_response) {
          double()
        }
        let(:expected_calls) { 1 }

        before do
          expect(expected_response).to receive(:response)
            .exactly(expected_calls).times
            .and_return(expected_response_response)

          expect(expected_response_response).to receive(:code)
            .exactly(expected_calls).times
            .and_return(expected_code)

          expect(HTTParty).to receive(:post)
            .with(
              expected_path,
              headers: expected_json_headers,
              body: expected_body
            )
            .exactly(expected_calls).times
            .and_return(expected_response)
        end
      end

      shared_context 'auth_token request with error' do
        let(:expected_code) { "404" }
        let(:expected_error) { StandardError.new("expected error") }
        include_context 'mocked auth token request'

        before do
          is_expected.to receive(:raise_dds_api_exception)
            .with("unable to get agent api_token", expected_response)
            .and_raise(expected_error)
        end
      end

      shared_context 'successfull auth_token request' do
        let(:expected_code) { "201" }
        include_context 'mocked auth token request'

        let(:expected_time_to_live) { 7200 }
        let(:expected_api_token_response) {
          {
            "api_token" => expected_api_token,
            "time_to_live" => expected_time_to_live
          }
        }

        before do
          expect(expected_response).to receive(:parsed_response)
            .exactly(expected_calls).times
            .and_return(expected_api_token_response)
        end
      end

      describe 'behavior' do
        context 'with incorrect credentials' do
          include_context 'auth_token request with error'

          it {
            expect {
              subject.auth_token
            }.to raise_error(expected_error)
          }
        end

        context 'with correct credentials' do
          include_context 'successfull auth_token request'

          context 'for the first time' do
            it 'should return an auth_token' do
              expect(subject.auth_token).to eq(expected_api_token)
            end
          end

          context 'when token is not expired' do
            before do
              subject.auth_token
            end

            it {
              expect(subject.auth_token).to eq(expected_api_token)
            }
          end

          context 'when token is expired' do
            let(:expected_calls) { 2 }
            before do
              subject.auth_token
            end

            it {
              travel_to(Time.now + 10000) do
                expect(subject.auth_token).to eq(expected_api_token)
              end
            }
          end
        end
      end
    end

    describe '#auth_header' do
      it { is_expected.to respond_to(:auth_header) }

      describe 'behavior' do
        before do
          is_expected.to receive(:auth_token)
            .and_return(expected_api_token)
          is_expected.to receive(:json_headers)
            .and_return(expected_json_headers)
        end
        it {
          expect(subject.auth_header).to eq(expected_auth_header)
        }
      end
    end

    shared_context 'a dds token authenticated request' do
      let(:expected_request_headers) {
        expected_auth_header
      }

      before do
        expect(reporter).to receive(:auth_header)
          .and_return(expected_auth_header)
      end
    end

    shared_examples 'a failed dds api request' do
      let(:failure_code) { "400" }
      let(:expected_error) { StandardError.new("failed dds api request") }
      let(:expected_response) {
        instance_double("HTTParty::Response")
      }
      let(:expected_response_response) {
        double()
      }

      before do
        expect(expected_response).to receive(:response)
          .and_return(expected_response_response)
        expect(expected_response_response).to receive(:code)
          .and_return(failure_code)
        expect(reporter).to receive(:raise_dds_api_exception)
          .with(expected_preamble, expected_response)
          .and_raise(expected_error)
        if (expected_http_verb == :get)
          expect(HTTParty).to receive(expected_http_verb)
            .with(expected_path, headers: expected_request_headers)
            .and_return(expected_response)
        else
          expect(HTTParty).to receive(expected_http_verb)
            .with(
              expected_path,
              headers: expected_request_headers,
              body: expected_body
            )
            .and_return(expected_response)
        end
      end

      it {
        expect {
          subject
        }.to raise_error(expected_error)
      }
    end

    describe '#file_version' do
      it { is_expected.to respond_to(:file_version) }

      describe 'behavior' do
        let(:expected_path) { "#{dds_api_url}/file_versions/#{file_version_id}" }
        subject {
          reporter.file_version
        }

        context 'with dds api error' do
          let(:expected_http_verb) { :get }
          let(:expected_preamble) { "unable to get file_version" }
          include_context 'a dds token authenticated request'
          it_behaves_like 'a failed dds api request'
        end
      end
    end

    describe '#download_url' do
      it { is_expected.to respond_to(:download_url) }

      describe 'behavior' do
        let(:expected_path) { "#{dds_api_url}/file_versions/#{file_version_id}/url" }
        subject {
          reporter.download_url
        }

        context 'with dds api error' do
          let(:expected_http_verb) { :get }
          let(:expected_preamble) { "unable to get download_url" }
          include_context 'a dds token authenticated request'
          it_behaves_like 'a failed dds api request'
        end
      end
    end

    describe '#upload' do
      it { is_expected.to respond_to(:upload) }

      describe 'behavior' do
        let(:expected_path) { "#{dds_api_url}/uploads/#{file_version["upload"]["id"]}" }
        subject {
          reporter.upload
        }

        before do
          expect(reporter).to receive(:file_version)
            .and_return(file_version)
        end

        context 'with dds api error' do
          let(:expected_http_verb) { :get }
          let(:expected_preamble) { "unable to get upload" }
          include_context 'a dds token authenticated request'
          it_behaves_like 'a failed dds api request'
        end
      end
    end

    describe '#chunk_text' do
      it { is_expected.to respond_to(:chunk_text) }

      describe 'behavior' do
        let(:expected_download_url) { 'http://download_url' }
        let(:expected_number) { 1 }
        let(:expected_hash) { "abc123xyz" }
        let(:chunk_summary) {
          {
            "size" => "1000",
            "number" => expected_number,
            "hash" => {
              "value" => expected_hash
            }
          }
        }
        let(:expected_chunk_start) { 0 }
        let(:expected_chunk_end) { expected_chunk_start + chunk_summary["size"].to_i - 1 }

        subject {
          reporter.chunk_text(chunk_summary, expected_chunk_start)
        }

        before do
          expect(reporter).to receive(:download_url)
            .and_return(expected_download_url)
        end

        context 'with dds api error' do
          let(:expected_http_verb) { :get }
          let(:expected_path) { expected_download_url }
          let(:expected_preamble) { "problem getting chunk #{chunk_summary["number"]} range #{expected_chunk_start}-#{expected_chunk_end}" }
          let(:expected_request_headers) {
            {
              "Range" => "bytes=#{expected_chunk_start}-#{expected_chunk_end}"
            }
          }
          it_behaves_like 'a failed dds api request'
        end
      end
    end

    describe '#upload_md5' do
      it { is_expected.to respond_to(:upload_md5) }

      describe 'behavior' do
        subject {
          reporter.upload_md5
        }

      end
    end
    describe '#report_md5' do
      it { is_expected.to respond_to(:report_md5) }

      describe 'behavior' do
        let(:expected_path) { "#{dds_api_url}/uploads/#{file_version["upload"]["id"]}/hashes" }
        let(:expected_upload_md5) { "abc123xyz" }
        subject {
          reporter.report_md5
        }

        before do
          expect(reporter).to receive(:file_version)
            .and_return(file_version)
          expect(reporter).to receive(:upload_md5)
            .and_return(expected_upload_md5)
        end

        context 'with dds api error' do
          let(:expected_http_verb) { :put }
          let(:expected_body) {
            {
              value: expected_upload_md5,
              algorithm: "md5"
            }.to_json
          }
          let(:expected_preamble) { "problem reporting md5" }
          include_context 'a dds token authenticated request'
          it_behaves_like 'a failed dds api request'
        end
      end
    end
  end
 end
