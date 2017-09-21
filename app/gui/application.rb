module Gui
  class Application
    Vedeu.configure do
      colour_mode 16777216
      interactive!
      fake!
    end

    Vedeu.bind(:_initialize_) do
      Vedeu.trigger(:_goto_, :chat, :show)
    end

    Vedeu.bind(:_command_) do |message|
      @engagement.send_message(message)
    end

    def self.start(engagement)
      @engagement = engagement
      @engagement.on_message do |message|
        Controllers::Chat::TRANSCRIPT.add_message(message)
      end
      Vedeu::Launcher.execute!
    end
  end
end
