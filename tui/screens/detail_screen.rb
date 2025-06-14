module WaniKaniTUI
  module TUI
    # Detail overview screen of a subject
    class DetailScreen
      attr_accessor :win

      def initialize(main)
        @main = main
        @win = Curses::Window.new(Curses.lines - 1, Curses.cols, 0, 0)
        @win.bkgd(Curses.color_pair(1))
      end

      def open(subject)
        draw
        @win.getch
      end

      private

      def draw
        @win.clear
        @win.refresh
      end
    end
  end
end
