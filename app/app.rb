require 'tty/prompt'
require 'httparty'
HTTParty::Basement.default_options.update(verify: false)
require 'securerandom'
require_relative './logger'
require_relative './engagement'
require_relative './gui'

class App
  USER_AGENT = 'SaleMove Console App'.freeze

  ENVIRONMENTS = {
    'Local' => { engagement_api: 'engagement.local.dev', api: 'api.local.dev' },
    'Acceptance' => { engagement_api: 'api.at.samo.io', api: 'api.at.samo.io' },
    'Beta' => { engagement_api: 'api.beta.salemove.com', api: 'api.beta.salemove.com' },
    'Prod US' => { engagement_api: 'api.salemove.com', api: 'api.salemove.com' },
    'Prod EU' => { engagement_api: 'api.salemove.eu', api: 'api.salemove.eu' }
  }

  def initialize(incoming_url)
    @incoming_url = incoming_url
    @prompt = TTY::Prompt.new
  end

  def run
    env = @prompt.select('SaleMove API location?', ENVIRONMENTS.keys)
    @api_url = ENVIRONMENTS[env].fetch(:api)
    @engagement_api_url = ENVIRONMENTS[env].fetch(:engagement_api)
    @site_id = ENV['SITE_ID'] || @prompt.ask('Site ID?')
    @operator_id = ENV['OPERATOR_ID'] || @prompt.ask('Operator ID?')
    @app_token = ENV['APP_TOKEN'] || @prompt.ask('Site Application Token?')

    info 'Creating a visitor...'
    create_visitor

    info 'Requesting an engagement...'
    create_engagement_request
  end

  def create_visitor
    response = HTTParty.post("https://#{@api_url}/visitors", {
      body: {}.to_json,
      headers: {
        'Authorization' => "ApplicationToken #{@app_token}",
        'Accept' => 'application/vnd.salemove.v1+json',
        'Content-Type' => 'application/json',
        'User-Agent' => USER_AGENT
      }
    })
    if (200..300).cover?(response.code)
      @visitor_id = response.parsed_response.fetch('id')
      @access_token = response.parsed_response.fetch('access_token')
    else
      error "Error requesting engagement: #{response.code} -- #{response.body}"
    end
  end

  def create_engagement_request
    @engagement_headers = {
      'Authorization' => "Bearer #{@access_token}",
      'Accept' => 'application/vnd.salemove.v1+json',
      'Content-Type' => 'application/json',
      'User-Agent' => USER_AGENT
    }

    response = HTTParty.post("https://#{@engagement_api_url}/engagement_requests", {
      body: {
        media: 'text',
        operator_id: @operator_id,
        site_id: @site_id,
        visitor_id: 'bee543e4-1451-4fdc-af14-77b9920e1c68',
        source: 'visitor_integrator',
        webhooks: [
          url: @incoming_url,
          method: 'POST',
          events: [
            'engagement.request.failure',
            'engagement.start',
            'engagement.transfer',
            'engagement.end',
            'engagement.chat.message',
            'engagement.chat.message_status'
          ]
        ]
      }.to_json,
      headers: @engagement_headers
    })
    if response.code == 201
      puts 'Engagement request created'
    else
      error "Error requesting engagement: #{response.code} -- #{response.body}"
    end
  end

  def on_webhook(payload)
    case payload['event_type']
    when 'engagement.request.failure'
      error "Engagement failed: #{payload.inspect}"
      exit 1
    when 'engagement.start'
      @engagement = Engagement.new(@engagement_api_url, payload['engagement']['id'], @engagement_headers)
      Gui::Application.start(@engagement)
    when 'engagement.chat.message'
      @engagement.receive_message(payload['message']['content'])
    when 'engagement.chat.message_status'
      @engagement.receive_message_status(payload['message']['id'], payload['message']['status'])
    when 'engagement.end'
      @engagement.receive_end
    else
      @engagement.receive_unhandled_webhook(payload.inspect)
    end
  end
end
