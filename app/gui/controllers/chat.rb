module Gui
  module Controllers
    class Chat < Vedeu::ApplicationController
      TRANSCRIPT = Views::Transcript.new

      controller_name :chat
      action :show

      def show
        Views::Input.new.render
        TRANSCRIPT.render
        Vedeu.focus_by_name(:input)
      end
    end
  end
end
