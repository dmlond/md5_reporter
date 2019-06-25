#!/usr/local/bin/ruby

require 'httparty'
require 'digest'

class DdsMd5Reporter
  def initialize(upload_id, user_key, agent_key, dds_api_url)
    @upload_id = upload_id
    @user_key = user_key
    @agent_key = agent_key
    @dds_api_url = dds_api_url

    @digest = Digest::MD5.new
  end

  def json_headers
   { 'Content-Type' => "application/json", 'Accept' => "application/json" }
  end

  def auth_token
    if @auth_token
      current = Time.now.to_i
      difference = current - @initialized_on
      if difference < @expires_in
        return @auth_token
      end
    end

    resp = HTTParty.post(
      "#{ENV['DDS_API_URL']}/software_agents/api_token",
      headers: json_headers,
      body: {
        agent_key: @agent_key,
        user_key: @user_key
      }.to_json
    )
    (resp.response.code.to_i == 201) || raise(StandardError, "#{resp.parsed_response["reason"]} #{resp.parsed_response["suggestion"]}")
    @initialized_on = Time.now.to_i
    token_payload = resp.parsed_response
    @auth_token = token_payload["api_token"]
    @expires_in = token_payload["time_to_live"]
    @auth_token
  end

  def auth_header
    {
      Authorization: auth_token
    }
  end

  def launch_worker
  end
end

if $0 == __FILE__
  upload_id = ARGV.shift
  DDSMD5Reporter.new(
    upload_id,
    ENV['BOT_KEY'],
    ENV['AGENT_KEY'],
    ENV['DDS_API_URL']
  ).launch_worker
end
