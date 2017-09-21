#!/usr/bin/env ruby

require 'ngrok/tunnel'
require 'json'
require_relative './app/logger'

Ngrok::Tunnel.start(port: 7676)
debug "Started ngrok @ #{Ngrok::Tunnel.ngrok_url_https}"

at_exit do
  debug "Shutting down ngrok"
  Ngrok::Tunnel.stop
end

require_relative './app/app'
demo = App.new(Ngrok::Tunnel.ngrok_url_https)

Thread.new do
  sleep 3
  demo.run
end

run ->(env) do
  req = Rack::Request.new(env)
  demo.on_webhook(JSON.parse(req.body.read))
  [204, {}, ['']]
end
