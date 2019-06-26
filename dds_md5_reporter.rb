#!/usr/local/bin/ruby

require 'httparty'
require 'digest'

class DdsMd5Reporter
  def initialize(file_version_id, user_key, agent_key, dds_api_url)
    usage = "file_version_id, user_key, agent_key, and dds_api_url cannot be nil"

    raise(ArgumentError, "missing file_version_id, #{usage}")
      unless file_version_id

    raise(ArgumentError, "missing user_key, #{usage}")
      unless user_key

    raise(ArgumentError, "missing agent_key, #{usage}")
      unless agent_key

    raise(ArgumentError, "missing dds_api_url, #{usage}")
      unless dds_api_url

    @file_version_id = file_version_id
    @user_key = user_key
    @agent_key = agent_key
    @dds_api_url = dds_api_url
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
      "#{@dds_api_url}/software_agents/api_token",
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
      'Authorization' => auth_token
    }.merge(json_headers)
  end
# swift 0-10 is the first 11 characters
# s3 0-10 is the first 11 characters
  def file_version
    return @file_version if @file_version
    resp = HTTParty.get("#{@dds_api_url}/file_versions/#{@file_version_id}", headers: auth_header)
    (resp.response.code.to_i == 200) || raise(StandardError, "#{resp.parsed_response["reason"]} #{resp.parsed_response["suggestion"]}")
    @file_version = resp.parsed_response
    @file_version
  end

  def download_url
    #always refresh
    resp = HTTParty.get("#{@dds_api_url}/file_versions/#{@file_version_id}/url", headers: auth_header)
    (resp.response.code.to_i == 200) || raise(StandardError, "#{resp.parsed_response["reason"]} #{resp.parsed_response["suggestion"]}")
    download_url_payload=resp.parsed_response
    "#{download_url_payload["host"]}#{download_url_payload["url"]}"
  end

  def upload
    return @upload if @upload
    resp = HTTParty.get("#{@dds_api_url}/uploads/#{file_version["upload"]["id"]}", headers: auth_header)
    (resp.response.code.to_i == 200) || raise(StandardError, "#{resp.parsed_response["reason"]} #{resp.parsed_response["suggestion"]}")
    @upload = resp.parsed_response
    @upload
  end

  def chunk_text(chunk_summary, chunk_start)
    chunk_end = chunk_start + chunk_summary["size"].to_i - 1

    resp = HTTParty.get(
      download_url,
      headers: {"Range" => "bytes=#{chunk_start}-#{chunk_end}"}
    )
    (resp.response.code.to_i == 206) || raise(StandardError, "problem getting range #{chunk_start}-#{chunk_end}")
    this_chunk = resp.body

    unless Digest::MD5.hexdigest(this_chunk) == chunk_summary["hash"]["value"]
      raise StandardError, "chunk #{chunk_summary["number"]} download md5 does not match reported md5!"
    end
    this_chunk
  end

  def upload_md5
    upload_digest = Digest::MD5.new
    chunk_start = 0
    # must download chunks in ascending order of number
    upload["chunks"].sort { |a,b|
      a["number"] <=> b["number"]
    }.each do |chunk_summary|
      upload_digest << chunk_text(chunk_summary, chunk_start)
      chunk_start += chunk_summary["size"].to_i
    end
    upload_digest.hexdigest
  end

  def report_md5
    resp = HTTParty.put(
      "#{@dds_api_url}/uploads/#{file_version["upload"]["id"]}/hashes",
      headers: auth_header,
      body: {
        value: upload_md5,
        algorithm: "md5"
      }.to_json
    )
    (resp.response.code.to_i == 200) || raise(StandardError, "problem reporting md5 #{resp.parsed_response}")
    resp.parsed_response
  end

  def launch_worker
  end
end

def usage
  $stderr.puts "usage: dds_md5_reporter <upload_id>
  requires the following Environment Variables
    USER_KEY: user key for duke data service user
    AGENT_KEY: software_agent key for duke data service
    DDS_API_URL: url to dds api (with protocol and /api/v1)
  "
  exit(1)
end

if $0 == __FILE__
  file_version_id = ARGV.shift or usage()
  begin
    DdsMd5Reporter.new(
      file_version_id: file_version_id,
      user_key: ENV['USER_KEY'],
      agent_key: ENV['AGENT_KEY'],
      dds_api_url: ENV['DDS_API_URL']
    ).launch_worker
  rescue ArgumentError => e
    $stderr.puts "#{e.message}"
    usage()
  end
end
