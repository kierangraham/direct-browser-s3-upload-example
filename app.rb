require 'sinatra'
require 'base64'
require 'openssl'
require 'cgi'

S3_KEY    = ENV['AWS_ACCESS_KEY']
S3_SECRET = ENV['AWS_SECRET']
S3_BUCKET = "/#{ENV['AWS_S3_BUCKET_NAME']}"

EXPIRE_TIME = (60 * 5) # 5 minutes
S3_URL      = 'http://s3.amazonaws.com'

get '/' do
  send_file 'index.html'
end

get '/styles.css' do
  send_file 'styles.css'
end

get '/app.js' do
  send_file 'app.js'
end

get '/signput' do
  objectName = "/#{params['name']}"

  mimeType = params['type']
  expires = Time.now.to_i + EXPIRE_TIME

  amzHeaders = "x-amz-acl:public-read"
  stringToSign = "PUT\n\n#{mimeType}\n#{expires}\n#{amzHeaders}\n#{S3_BUCKET}#{objectName}";
  sig = CGI::escape(Base64.strict_encode64(OpenSSL::HMAC.digest('sha1', S3_SECRET, stringToSign)))

  CGI::escape("#{S3_URL}#{S3_BUCKET}#{objectName}?AWSAccessKeyId=#{S3_KEY}&Expires=#{expires}&Signature=#{sig}")
end
