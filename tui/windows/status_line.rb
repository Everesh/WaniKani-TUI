require 'curses'

require_relative '../components/spinner'

module WaniKaniTUI
  module TUI
    # Provides feedback on state of the app
    class StatusLine
      attr_accessor :win

      def initialize(preferences, cjk_renderer)
        @preferences = preferences
        @cjk_renderer = cjk_renderer
        @win = Curses::Window.new(3, Curses.cols, Curses.lines - 3, 0)
        @spinner = Spinner.new(@win, 1, 2)
      end

      def status(process_message)
        @spinner.start
        @win.setpos(1, 5)
        @win.clrtoeol
        @win.addstr(process_message)
        @win.refresh
      end

      def state(state_message)
        clear
        @win.setpos(1, 2)
        @win.addstr('⢊')
        @win.setpos(1, 5)
        @win.clrtoeol
        @win.addstr(state_message)
        @win.refresh
      end

      def clear
        @spinner.stop
        @win.clear
        @win.refresh
      end
    end
  end
end
