require 'curses'

module WaniKaniTUI
  module TUI
    # The main Curses TUI application class.
    class ReviewScreen
      attr_accessor :win

      def initialize(main)
        @main = main
        @win = Curses::Window.new(Curses.lines - 1, Curses.cols, 0, 0)
      end

      def open
        draw
        while ch = @win.getch
          case ch
          when 27
            @main.overlays['main_menu'].open
          else
            # TODO
          end
          draw
        end
      end

      private

      def draw
        @win.keypad(true) # Refocuses keypad to avoid misscapture from main_menu
        @win.clear
        @win.refresh
      end
    end
  end
end
