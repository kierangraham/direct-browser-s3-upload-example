require 'typhoeus'
require 'sinatra'
require 'base64'
require 'openssl'
require 'cgi'
require 'json'

S3_KEY    = ENV['AWS_ACCESS_KEY']
S3_SECRET = ENV['AWS_SECRET']
S3_BUCKET = "/#{ENV['AWS_S3_BUCKET_NAME']}"

EXPIRE_TIME = (60 * 5) # 5 minutes
S3_URL      = 'http://s3.amazonaws.com'

# S3 Signing
get '/signput' do
  objectName = "/#{params['name']}"

  mimeType = params['type']
  expires = Time.now.to_i + EXPIRE_TIME

  amzHeaders = "x-amz-acl:public-read"
  stringToSign = "PUT\n\n#{mimeType}\n#{expires}\n#{amzHeaders}\n#{S3_BUCKET}#{objectName}";
  sig = CGI::escape(Base64.strict_encode64(OpenSSL::HMAC.digest('sha1', S3_SECRET, stringToSign)))

  CGI::escape("#{S3_URL}#{S3_BUCKET}#{objectName}?AWSAccessKeyId=#{S3_KEY}&Expires=#{expires}&Signature=#{sig}")
end

# Upload Complete
post '/upload/complete/:name' do
  file = params['name']
  uuid = file.split(".").first

  encode_request =
  {
    input: "s3://#{ENV['AWS_S3_BUCKET_NAME']}/#{file}",
    outputs: [
      {
        label: "low",
        public: 1,
        format: "mp4",
        quality: 1,
        audio_sample_rate: 22050,
        url: "s3://#{ENV['AWS_S3_BUCKET_NAME']}/#{uuid}/low.mp4",
        audio_bitrate: 64,
        video_bitrate: 300,
        decimate: 2,
        width: 480
      },
      {
        label: "high",
        public: 1,
        format: "mp4",
        quality: 4,
        url: "s3://#{ENV['AWS_S3_BUCKET_NAME']}/#{uuid}/high.mp4",
        h264_profile: "baseline",
        audio_bitrate: 128,
        video_bitrate: 1200,
        width: 1024,
      },
      {
        public: 1,
        source: "low",
        format: "ts",
        url: "s3://#{ENV['AWS_S3_BUCKET_NAME']}/#{uuid}/hls-low.m3u8",
        label: "hls-low",
        type: "segmented",
        hls_optimized_ts: true,
        video_bitrate: 64
      },
      {
        public: 1,
        source: "high",
        format: "ts",
        url: "s3://#{ENV['AWS_S3_BUCKET_NAME']}/#{uuid}/hls-medium.m3u8",
        label: "hls-medium",
        type: "segmented",
        hls_optimized_ts: true,
        video_bitrate: 600
      },
      {
        public: 1,
        source: "high",
        format: "ts",
        url: "s3://#{ENV['AWS_S3_BUCKET_NAME']}/#{uuid}/hls-high.m3u8",
        label: "hls-high",
        type: "segmented",
        hls_optimized_ts: true,
        video_bitrate: 1200
      },
      {
        public: 1,
        base_url: "s3://#{ENV['AWS_S3_BUCKET_NAME']}/#{uuid}/",
        streams: [
           {
              path: "hls-low.m3u8",
              bandwidth: 64
           },
           {
              path: "hls-medium.m3u8",
              bandwidth: 600
           },
           {
              path: "hls-high.m3u8",
              bandwidth: 1200
           }
        ],
        type: "playlist",
        url: "s3://#{ENV['AWS_S3_BUCKET_NAME']}/#{uuid}/playlist.m3u8"
      }
    ],
    notifications: [
      "#{ZENCODER_NOTIFY_EMAIL}",
      {
        format: "json",
        url: "#{ZENCODER_NOTIFY_URL}"
      }
    ]
  }.to_json

  response = Typhoeus::Request.post("https://app.zencoder.com/api/v2/jobs", :headers => { "Zencoder-Api-Key" => ENV['ZENCODER_API_KEY'] }, :body => encode_request)

  STDERR.puts "UPLOAD COMPLETE => ZENCODER RESPONSE:"
  STDERR.puts response.body
end

# Transcoding Complete
post '/transcoding/complete' do
  STDERR.puts "TRANSCODING COMPLETE => ZENCODER RESPONSE:"
  STDERR.puts request.body
end

get '/' do
  send_file 'index.html'
end

get '/styles.css' do
  send_file 'styles.css'
end

get '/app.js' do
  send_file 'app.js'
end