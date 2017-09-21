require 'tty/prompt'
require 'httparty'
require 'securerandom'
require_relative './logger'
require_relative './engagement'
require_relative './gui'

class App
  DEV_ENGAGEMENT_API = 'engagement.local.dev'
  DEV_LEGACY_API = 'api.local.dev'

  API_LOCATIONS = [
    DEV_ENGAGEMENT_API,
    'api.at.samo.io',
    'api.beta.salemove.com',
    'api.salemove.com',
    'api.salemove.eu'
  ].freeze

  def initialize(incoming_url)
    @incoming_url = incoming_url
    @prompt = TTY::Prompt.new
  end

  def run
    @server = @prompt.select('SaleMove API location?', API_LOCATIONS)
    @site_id = ENV['SITE_ID'] || @prompt.ask('Site ID?')
    @dev_token = ENV['DEV_TOKEN'] || @prompt.ask('Dev Token?')
    pick_operator

    info "Requesting engagement..."
    create_engagement_request
  end

  def pick_operator
    if ENV['OPERATOR_ID']
      @operator_id = ENV['OPERATOR_ID']
      return
    end

    server = DEV_LEGACY_API if @server == DEV_ENGAGEMENT_API
    response = HTTParty.get("https://#{server}/operators?include_offline=false&site_ids[]=#{@site_id}", {
      headers: {
        'Authorization' => "Token #{@dev_token}",
        'Accept' => 'application/vnd.salemove.v1+json'
      }
    })
    if response.code != 200
      error "Error fetching site operators: #{response.code} #{response.body}"
      exit 1
    end

    if response['operators'].size == 0
      error 'No online operators'
      exit 1
    end

    @operator_id = response['operators'].first['id']
  end

  def create_engagement_request
    response = HTTParty.post("https://#{@server}/engagement_requests", {
      body: {
        media: 'text',
        operator_id: @operator_id,
        new_site_visitor: {
          site_id: @site_id,
          name: 'Demo Visitor'
        },
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
      },
      headers: {
        'Authorization' => "Token #{@dev_token}",
        'Accept' => 'application/vnd.salemove.v1+json'
      }
    })
    if response.code == 201
      @authentication_headers = response['visitor_authentication']
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
      @engagement = Engagement.new(@server, payload['engagement']['id'], @authentication_headers)
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
