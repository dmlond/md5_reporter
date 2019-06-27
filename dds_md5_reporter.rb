#!/usr/local/bin/ruby

require 'httparty'
require 'digest'

class DdsMd5Reporter
  def initialize(file_version_id:, user_key:, agent_key:, dds_api_url:)
    usage = "file_version_id, user_key, agent_key, and dds_api_url cannot be nil"

    raise(ArgumentError, "missing file_version_id, #{usage}") unless file_version_id

    raise(ArgumentError, "missing user_key, #{usage}") unless user_key

    raise(ArgumentError, "missing agent_key, #{usage}") unless agent_key

    raise(ArgumentError, "missing dds_api_url, #{usage}") unless dds_api_url

    @file_version_id = file_version_id
    @user_key = user_key
    @agent_key = agent_key
    @dds_api_url = dds_api_url
  end

  def raise_dds_api_exception(preamble, resp)
    if resp.body.match(/error.*reason.*suggestion/)
      dds_error = resp.parsed_response
      raise(
        StandardError,
        "#{preamble}: #{dds_error["reason"]} #{dds_error["suggestion"]}"
      )
    else
      raise(StandardError, "#{preamble}: #{resp.response}")
    end
  end

  def json_headers
   {
     'Content-Type' => "application/json",
     'Accept' => "application/json"
   }
  end

  def auth_token
    if @auth_token
      current = Time.now.to_i
      difference = current - @initialized_on
      if difference < @expires_in
        return @auth_token
      end
    end

    path = "#{@dds_api_url}/software_agents/api_token"
    payload = {
      agent_key: @agent_key,
      user_key: @user_key
    }.to_json
    resp = dds_api :post, path, json_headers, payload
    (resp.response.code.to_i == 201) || raise_dds_api_exception(
      "unable to get agent api_token", resp
    )

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

  def call_external(verb, path, headers=nil, body=nil)
    if headers && body
      HTTParty.send(
        verb,
        path,
        headers: headers,
        body: body
      )
    elsif headers
      HTTParty.send(
        verb,
        path,
        headers: headers
      )
    elsif body
      HTTParty.send(
        verb,
        path,
        body: body
      )
    else
      HTTParty.send(
        verb,
        path
      )
    end
  end

  def dds_api(verb, path, headers=nil, body=nil)
    headers ||= auth_header
    call_external(verb, path, headers, body)
  end

  def file_version
    return @file_version if @file_version
    resp = dds_api :get, "#{@dds_api_url}/file_versions/#{@file_version_id}"
    (resp.response.code.to_i == 200) || raise_dds_api_exception(
      "unable to get file_version", resp
    )
    @file_version = resp.parsed_response
    @file_version
  end

  def download_url
    #always refresh
    resp = dds_api :get, "#{@dds_api_url}/file_versions/#{@file_version_id}/url"
    (resp.response.code.to_i == 200) || raise_dds_api_exception(
      "unable to get download_url", resp
    )
    download_url_payload=resp.parsed_response
    "#{download_url_payload["host"]}#{download_url_payload["url"]}"
  end

  def upload
    return @upload if @upload
    resp = dds_api :get, "#{@dds_api_url}/uploads/#{file_version["upload"]["id"]}"
    (resp.response.code.to_i == 200) || raise_dds_api_exception(
      "unable to get upload", resp
    )
    @upload = resp.parsed_response
    @upload
  end

  def chunk_text(chunk_summary, chunk_start)
    chunk_end = chunk_start + chunk_summary["size"].to_i - 1

    headers = {"Range" => "bytes=#{chunk_start}-#{chunk_end}"}
    resp = call_external :get, download_url, headers
    (resp.response.code.to_i == 206) || raise_dds_api_exception(
      "problem getting chunk #{chunk_summary["number"]} range #{chunk_start}-#{chunk_end}", resp
    )
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
    path = "#{@dds_api_url}/uploads/#{file_version["upload"]["id"]}/hashes"
    payload = {
      value: upload_md5,
      algorithm: "md5"
    }.to_json
    resp = dds_api :put, path, nil, payload
    (resp.response.code.to_i == 200) || raise_dds_api_exception(
      "problem reporting md5", resp
    )
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
    ).report_md5
    puts "md5 reported"
  rescue ArgumentError => e
    $stderr.puts "#{e.message}"
    usage()
  end
end
