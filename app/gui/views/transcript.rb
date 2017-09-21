module Gui
  module Views
    class Transcript < Vedeu::ApplicationView
      def initialize(*)
        super
        @messages = [
          {sender: :system, content: 'Engagement has started, type to send a message'}
        ]
      end

      def add_message(message)
        @messages << message
        render
      end

      def render
        messages = @messages # instance variables not accessible in render block

        Vedeu.render do
          view :transcript do
            lines do
              messages.each do |message|
                line do
                  case message[:sender]
                  when :operator
                    left '< ', foreground: '#ffffff'
                    left message[:content], foreground: '#00ffff'
                  when :visitor
                    left '> ', foreground: '#ffffff'
                    left message[:content], foreground: '#00ff00'
                  when :system
                    left '| ', foreground: '#ffffff'
                    left message[:content], foreground: '#ffffe0'
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
