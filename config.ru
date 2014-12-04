require 'rubygems'
require 'bundler'
Bundler.require

require 'digest/sha1'
require 'json'

class Download < Sinatra::Base
  register Sinatra::Async

  SITE_HOST = 'personalsam.com'
  DOWNLOAD_HOST = 'download.personalsam.com'
  MIXPANEL_TOKEN = ENV['MIXPANEL_TOKEN']
  DOWNLOAD_SHARED_SECRET = ENV['DOWNLOAD_SHARED_SECRET']

  aget '/' do
    redirect "#{request.scheme}://#{SITE_HOST}/"
  end

  aget '/video.:format' do
    # Get params
    url, slug, type, signature = params[:url], params[:slug], params[:type], params[:signature]
    error('Bad Request') and return unless url && slug && type && signature

    # Check Signature
    correct = Digest::SHA1.hexdigest DOWNLOAD_SHARED_SECRET + url + slug + type
    error('Invalid Signature') and return unless correct == signature

    # Create payload
    params = {
      event: 'Episode Download',
      properties: {
        token: MIXPANEL_TOKEN,
        'Episode': slug,
        'Type': type,
        time: Time.now.to_i,
        ip: request.ip
      }
    }

    # Report to Mixpanel
    if data = Base64.strict_encode64(JSON.dump(params))
      EventMachine::HttpRequest.new("http://api.mixpanel.com/track/?data=#{data}").get
    end

    # Redirect to the URL
    redirect url
  end

  aget '*' do
    error('Not Found', 404)
  end

  private

  def error(message, status=400)
    content_type 'text/plain'
    ahalt status, message
  end
end

run Download.new
