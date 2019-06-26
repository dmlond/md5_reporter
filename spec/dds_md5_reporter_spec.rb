require 'active_support'
require 'active_support/testing/time_helpers'
require_relative '../dds_md5_reporter'

describe DdsMd5Reporter do
  include ActiveSupport::Testing::TimeHelpers

  let(:upload_id) { 'UPLOAD_ID' }
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

  describe 'required arguments' do
    context 'missing upload_id' do
      subject { DdsMd5Reporter.new }
      it 'should raise an error' do
        expect {
          subject
        }.to raise_error ArgumentError, "missing keywords: upload_id, user_key, agent_key, dds_api_url"
      end
    end

    context 'nil user_key' do
      subject {
        DdsMd5Reporter.new(
          upload_id: upload_id,
          user_key: nil,
          agent_key: agent_key,
          dds_api_url: dds_api_url
        )
      }
      it 'should raise an error' do
        expect {
          subject
        }.to raise_error ArgumentError, "upload_id, user_key, agent_key, and dds_api_url cannot be nil"
      end
    end

    context 'nil agent_key' do
      subject {
        DdsMd5Reporter.new(
          upload_id: upload_id,
          user_key: user_key,
          agent_key: nil,
          dds_api_url: dds_api_url
        )
      }
      it 'should raise an error' do
        expect {
          subject
        }.to raise_error ArgumentError, "upload_id, user_key, agent_key, and dds_api_url cannot be nil"
      end
    end

    context 'nil dds_api_url' do
      subject {
        DdsMd5Reporter.new(
          upload_id: upload_id,
          user_key: user_key,
          agent_key: agent_key,
          dds_api_url: nil
        )
      }
      it 'should raise an error' do
        expect {
          subject
        }.to raise_error ArgumentError, "upload_id, user_key, agent_key, and dds_api_url cannot be nil"
      end
    end

    context 'all present' do
      subject {
        DdsMd5Reporter.new(
          upload_id: upload_id,
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
    subject {
      DdsMd5Reporter.new(
        upload_id: upload_id,
        user_key: user_key,
        agent_key: agent_key,
        dds_api_url: dds_api_url
      )
    }

    describe '#json_headers' do
      it { is_expected.to respond_to(:json_headers) }
      it { expect(subject.json_headers).to eq(expected_json_headers) }
    end

    describe '#auth_token' do
      it { is_expected.to respond_to(:auth_token) }

      shared_context 'mocked auth token request' do
        let(:expected_path) { "#{ENV['DDS_API_URL']}/software_agents/api_token" }
        let(:expected_body) {
          {
            agent_key: agent_key,
            user_key: user_key
          }.to_json
        }
        let(:expected_response) {
          instance_double("HTTParty::Response")
        }
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
        let(:expected_time_to_live) { 7200 }
        let(:expected_api_token_response) {
          {
            "api_token" => expected_api_token,
            "time_to_live" => expected_time_to_live
          }
        }
        let(:expected_calls) { 1 }

        before do
          expect(expected_response).to receive(:response)
            .exactly(expected_calls).times
            .and_return(expected_response_response)

          expect(expected_response_response).to receive(:code)
            .exactly(expected_calls).times
            .and_return("201")

          expect(expected_response).to receive(:parsed_response)
            .exactly(expected_calls).times
            .and_return(expected_api_token_response)

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

      describe 'called' do
        include_context 'mocked auth token request'

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

    describe '.launch_worker' do
      it { is_expected.to respond_to(:launch_worker) }
    end
  end
 end
