class Engagement
  def initialize(server, id, headers)
    @server = server
    @id = id
    @headers = headers
    @message_listeners = []
  end

  def receive_end
    notify(sender: :system, content: 'Engagement has ended, please leave!')
  end

  def receive_unhandled_webhook(payload)
    notify(sender: :system, content: "Unhandled webhook: #{payload}")
  end

  def receive_message(content)
    notify(sender: :operator, content: content)
  end

  def receive_message_status(id, status)
    notify(sender: :system, content: "Message #{id} has been marked '#{status}'")
  end

  def send_message(content)
    notify(sender: :visitor, content: content)

    message_id = SecureRandom.uuid
    response = HTTParty.put(
      "https://#{@server}/engagements/#{@id}/chat_messages/#{message_id}",
      body: { content: content }.to_json,
      headers: @headers
    )
    if response.code != 200
      notify(sender: :system, content: "Error sending chat message! code:#{response.code} body:#{response.body}")
    end
  end

  def on_message(&block)
    @message_listeners << block
  end

  def notify(message)
    @message_listeners.each do |listener|
      listener.call(message)
    end
  end
end
