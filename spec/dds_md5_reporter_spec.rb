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
        }.to raise_error ArgumentError, "missing file_version_id. The keywords file_version_id, user_key, agent_key, and dds_api_url cannot be nil."
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
        }.to raise_error ArgumentError, "missing user_key. The keywords file_version_id, user_key, agent_key, and dds_api_url cannot be nil."
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
        }.to raise_error ArgumentError, "missing agent_key. The keywords file_version_id, user_key, agent_key, and dds_api_url cannot be nil."
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
        }.to raise_error ArgumentError, "missing dds_api_url. The keywords file_version_id, user_key, agent_key, and dds_api_url cannot be nil."
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

    shared_context 'a success response' do
      let(:expected_response) {
        instance_double("HTTParty::Response")
      }
      let(:expected_response_response) {
        double()
      }

      before do
        expect(expected_response).to receive(:response)
          .exactly(expected_calls).times
          .and_return(expected_response_response)
        expect(expected_response_response).to receive(:code)
          .exactly(expected_calls).times
          .and_return(expected_success_code)
      end
    end

    shared_context 'a failure response' do
      let(:failure_code) { "400" }
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
      end
    end

    shared_examples 'a failed external call' do
      let(:expected_error) { StandardError.new("failed dds api request") }
      include_context 'a failure response'
      before do
        expect(reporter).to receive(:raise_dds_api_exception)
          .with(expected_preamble, expected_response)
          .and_raise(expected_error)

        if expected_body && expected_request_headers
          expect(reporter).to receive(expected_reporter_call_method)
            .with(
              expected_http_verb,
              expected_path,
              expected_request_headers,
              expected_body
            ).and_return(expected_response)
        elsif expected_request_headers
          expect(reporter).to receive(expected_reporter_call_method)
            .with(
              expected_http_verb,
              expected_path,
              expected_request_headers
            ).and_return(expected_response)
        elsif expected_body
          expect(reporter).to receive(expected_reporter_call_method)
            .with(
              expected_http_verb,
              expected_path,
              nil,
              expected_body
            ).and_return(expected_response)
        else
          expect(reporter).to receive(expected_reporter_call_method)
            .with(
              expected_http_verb,
              expected_path
            ).and_return(expected_response)
        end
      end

      it {
        expect {
          subject
        }.to raise_error(expected_error)
      }
    end

    shared_examples 'a failed dds api request' do
      let(:expected_reporter_call_method) { :dds_api }
      it_behaves_like 'a failed external call'
    end

    shared_examples 'a method with a cached response' do
      # these methods are expected to only call dds_api and
      # parse its response once, and then cache the parsed_esponse
      # to be returned on subsequent calls
      let(:expected_calls) { 1 }
      include_context 'a success response'
      context 'initial call' do
        it {
          expect(reporter).to receive(:dds_api)
            .with(*expected_dds_api_arguments)
            .and_return(expected_response)
          expect(expected_response)
            .to receive(:parsed_response)
            .and_return(expected_response_payload)
          is_expected.to eq(expected_method_response)
        }
      end

      context 'additional call after initial call' do
        it {
          expect(reporter).to receive(:dds_api)
            .with(*expected_dds_api_arguments)
            .exactly(1).times
            .and_return(expected_response)
          expect(expected_response)
            .to receive(:parsed_response)
            .exactly(1).times
            .and_return(expected_response_payload)
          expect(initial_call).to eq(expected_method_response)
          expect(subsequent_call).to eq(expected_method_response)
        }
      end
    end

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

      describe 'behavior' do
        let(:expected_path) { "#{dds_api_url}/software_agents/api_token" }
        let(:expected_http_verb) { :post }
        let(:expected_time_to_live) { 7200 }
        let(:expected_response_payload) {
          {
            "api_token" => expected_api_token,
            "time_to_live" => expected_time_to_live
          }
        }
        let(:expected_method_response) { expected_api_token }
        let(:expected_body) {
          {
            "agent_key" => agent_key,
            "user_key" => user_key
          }.to_json
        }
        let(:expected_request_headers) { expected_json_headers }
        subject {
          reporter.auth_token
        }

        context 'with incorrect credentials' do
          let(:expected_preamble) { "unable to get agent api_token" }
          it_behaves_like 'a failed dds api request'
        end

        context 'with correct credentials' do
          let(:expected_success_code) { "201" }
          let(:expected_dds_api_arguments) {[expected_http_verb, expected_path, expected_json_headers, expected_body]}
          let(:initial_call) {
            reporter.auth_token
          }
          let(:subsequent_call) {
            reporter.auth_token
          }

          context 'when called again and time has not passed enough to cause the cached token to be expired' do
            it_behaves_like 'a method with a cached response'
          end

          context 'when called again and enough time has passed to cause the cached token to be expired' do
            # this method calls the api for a new token using the agent_key
            # and user_key if the enough time has passed between when the
            # original token was cached to cause it to be expired based on
            # the time_to_live returned by the api
            let(:expected_calls) { 2 }
            include_context 'a success response'
            it 'is expected to call the dds_api again'  do
              expect(reporter).to receive(:dds_api)
                .with(*expected_dds_api_arguments)
                .exactly(expected_calls).times
                .and_return(expected_response)
              expect(expected_response)
                .to receive(:parsed_response)
                .exactly(expected_calls).times
                .and_return(expected_response_payload)

              expect(initial_call).to eq(expected_method_response)

              initialized_on = Time.now.to_i
              travel_to(Time.now + 10000) do
                current = Time.now.to_i
                difference = current - initialized_on
                expect(difference).not_to be < expected_time_to_live
                expect(subsequent_call).to eq(expected_method_response)
              end
            end
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

    describe '#call_external' do
      it { is_expected.to respond_to(:call_external) }

      describe 'behavior' do
        let(:expected_verb) { :verb }
        let(:expected_path) { 'path' }
        let(:expected_response) { 'expected_response' }
        context 'with headers and body' do
          let(:expected_headers) { 'expected_headers' }
          let(:expected_body) { 'expected body' }
          before do
            expect(HTTParty).to receive(:send)
              .with(
                expected_verb,
                expected_path,
                headers: expected_headers,
                body: expected_body
              ).and_return(expected_response)
          end
          it {
            expect(
              subject.call_external(
                expected_verb,
                expected_path,
                expected_headers,
                expected_body
              )
            ).to eq(expected_response)
          }
        end

        context 'with header only' do
          let(:expected_headers) { 'expected_headers' }
          before do
            expect(HTTParty).to receive(:send)
              .with(
                expected_verb,
                expected_path,
                headers: expected_headers
              ).and_return(expected_response)
          end

          it {
            expect(
              subject.call_external(
                expected_verb,
                expected_path,
                expected_headers
              )
            ).to eq(expected_response)
          }
        end

        context 'with body only' do
          let(:expected_body) { 'expected body' }
          before do
            expect(HTTParty).to receive(:send)
              .with(
                expected_verb,
                expected_path,
                body: expected_body
              ).and_return(expected_response)
          end
          it {
            expect(
              subject.call_external(
                expected_verb,
                expected_path,
                nil,
                expected_body
              )
            ).to eq(expected_response)
          }
        end

        context 'without header or body' do
          before do
            expect(HTTParty).to receive(:send)
              .with(
                expected_verb,
                expected_path
              ).and_return(expected_response)
          end
          it {
            expect(
              subject.call_external(
                expected_verb,
                expected_path
              )
            ).to eq(expected_response)
          }
        end
      end
    end

    describe 'dds_api' do
      it { is_expected.to respond_to(:dds_api) }

      describe 'behavior' do
        let(:expected_verb) { :verb }
        let(:expected_path) { 'path' }
        let(:expected_response) { 'expected_response' }

        context 'with headers and body' do
          let(:expected_headers) { 'expected_headers' }
          let(:expected_body) { 'expected body' }
          before do
            expect(reporter).to receive(:call_external)
              .with(
                expected_verb,
                expected_path,
                expected_headers,
                expected_body
              ).and_return(expected_response)
          end
          it {
            expect(
              subject.dds_api(
                expected_verb,
                expected_path,
                expected_headers,
                expected_body
              )
            ).to eq(expected_response)
          }
        end

        context 'with header only' do
          let(:expected_headers) { 'expected_headers' }
          before do
            expect(reporter).to receive(:call_external)
              .with(
                expected_verb,
                expected_path,
                expected_headers,
                nil
              ).and_return(expected_response)
          end

          it {
            expect(
              subject.dds_api(
                expected_verb,
                expected_path,
                expected_headers
              )
            ).to eq(expected_response)
          }
        end

        context 'with body only' do
          let(:expected_body) { 'expected body' }
          before do
            expect(reporter).to receive(:auth_header)
              .and_return(expected_auth_header)
            expect(reporter).to receive(:call_external)
              .with(
                expected_verb,
                expected_path,
                expected_auth_header,
                expected_body
              ).and_return(expected_response)
          end
          it {
            expect(
              subject.dds_api(
                expected_verb,
                expected_path,
                nil,
                expected_body
              )
            ).to eq(expected_response)
          }
        end

        context 'without header or body' do
          before do
            expect(reporter).to receive(:auth_header)
              .and_return(expected_auth_header)
            expect(reporter).to receive(:call_external)
              .with(
                expected_verb,
                expected_path,
                expected_auth_header,
                nil
              ).and_return(expected_response)
          end
          it {
            expect(
              subject.dds_api(
                expected_verb,
                expected_path
              )
            ).to eq(expected_response)
          }
        end
      end
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
          let(:expected_body) { nil }
          let(:expected_request_headers) { nil }
          let(:expected_preamble) { "unable to get file_version" }
          it_behaves_like 'a failed dds api request'
        end

        context 'without dds api error' do
          let(:expected_success_code) { "200" }
          let(:expected_verb) { :get }
          let(:expected_path) { "#{dds_api_url}/file_versions/#{file_version_id}" }
          let(:expected_response_payload) { file_version }
          let(:expected_method_response) { file_version }
          let(:initial_call) {
            reporter.file_version
          }
          let(:subsequent_call) {
            reporter.file_version
          }
          let(:expected_dds_api_arguments) {[expected_verb, expected_path]}
          it_behaves_like 'a method with a cached response'
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
          let(:expected_body) { nil }
          let(:expected_request_headers) { nil }
          let(:expected_preamble) { "unable to get download_url" }
          it_behaves_like 'a failed dds api request'
        end

        context 'without dds api error' do
          let(:expected_success_code) { "200" }
          let(:expected_calls) { 1 }
          let(:expected_verb) { :get }
          let(:expected_path) { "#{dds_api_url}/file_versions/#{file_version_id}/url" }
          let(:expected_host) { 'http://exected_host' }
          let(:expected_url) { '/expected_url' }
          let(:expected_payload) {
            {
              "host" => expected_host,
              "url" => expected_url
            }
          }
          let(:expected_download_url) { "#{expected_host}#{expected_url}" }
          include_context 'a success response'

          before do
            expect(reporter).to receive(:dds_api)
              .with(expected_verb, expected_path)
              .and_return(expected_response)
            expect(expected_response)
              .to receive(:parsed_response)
              .and_return(expected_payload)
          end

          it {
            is_expected.to eq(expected_download_url)
          }
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
          let(:expected_body) { nil }
          let(:expected_request_headers) { nil }
          let(:expected_preamble) { "unable to get upload" }
          it_behaves_like 'a failed dds api request'
        end

        context 'without dds api error' do
          let(:expected_success_code) { "200" }
          let(:expected_verb) { :get }
          let(:expected_path) { "#{dds_api_url}/uploads/#{file_version["upload"]["id"]}" }
          let(:expected_response_payload) { {"id": "foo", "dds_kind": "upload"} }
          let(:expected_method_response) { expected_response_payload }
          let(:initial_call) {
            reporter.upload
          }
          let(:subsequent_call) {
            reporter.upload
          }
          let(:expected_dds_api_arguments) {[expected_verb, expected_path]}
          it_behaves_like 'a method with a cached response'
        end
      end
    end

    describe '#chunk_text' do
      it { is_expected.to respond_to(:chunk_text) }

      describe 'behavior' do
        let(:expected_download_url) { 'http://download_url' }
        let(:expected_number) { 1 }
        let(:chunk_text) { 'chunk_text' }
        let(:expected_hash) { Digest::MD5.hexdigest(chunk_text) }
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
        let(:expected_http_verb) { :get }
        let(:expected_path) { expected_download_url }
        let(:expected_request_headers) {
          {
            "Range" => "bytes=#{expected_chunk_start}-#{expected_chunk_end}"
          }
        }

        subject {
          reporter.chunk_text(chunk_summary, expected_chunk_start)
        }

        before do
          expect(reporter).to receive(:download_url)
            .and_return(expected_download_url)
        end

        context 'with call_external error' do
          let(:expected_body) { nil }
          let(:expected_preamble) { "problem getting chunk #{chunk_summary["number"]} range #{expected_chunk_start}-#{expected_chunk_end}" }
          let(:expected_reporter_call_method) { :call_external }
          it_behaves_like 'a failed external call'
        end

        context 'without call_external error' do
          let(:expected_success_code) { "206" }
          let(:expected_calls) { 1 }
          include_context 'a success response'
          before do
            expect(reporter).to receive(:call_external)
              .with(expected_http_verb, expected_path, expected_request_headers)
              .and_return(expected_response)
            expect(expected_response).to receive(:body)
              .and_return(chunk_text)
          end

          context 'chunk md5 mactches md5 of downloaded chunk_text' do
            it {
              is_expected.to eq(chunk_text)
            }
          end

          context 'chunk md5 does not match md5 of downloaded chunk_text' do
            let(:expected_hash) { 'wrong hash' }
            it {
              expect {
                subject
              }.to raise_error(StandardError, "chunk #{chunk_summary["number"]} download md5 does not match reported md5!")
            }
          end
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
          let(:expected_request_headers) { nil }
          let(:expected_preamble) { "problem reporting md5" }
          it_behaves_like 'a failed dds api request'
        end
      end
    end
  end
 end
