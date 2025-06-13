require 'curses'

module WaniKaniTUI
  module TUI
    # The main Curses TUI application class.
    class Review
      attr_accessor :win

      def initialize(main)
        @main = main
        @win = Curses::Window.new(Curses.lines - 1, Curses.cols, 0, 0)
        draw
      end

      def draw
        @win.setpos(10, 10)
        @win.addstr('test')
        @win.refresh
        main_loop
      end

      def main_loop
        case @win.getch
        when 27 # escape key
          return @main.main_menu
        else
          # to do
        end
        draw
      end
    end
  end
end
