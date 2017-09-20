module Gui
  module Views
    class Input < Vedeu::ApplicationView
      def render
        Vedeu.render do
          view :input do
          end
        end
      end
    end
  end
end
