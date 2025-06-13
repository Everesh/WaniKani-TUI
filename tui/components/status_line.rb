# frozen_string_literal: true

require 'curses'
require 'time'

require_relative 'spinner'

module WaniKaniTUI
  module TUI
    # Provides feedback on state of the app
    class StatusLine
      attr_accessor :win

      def initialize(main)
        @main = main
        @win = Curses::Window.new(1, Curses.cols, Curses.lines - 1, 0)
        @spinner = Spinner.new(@win, 0, 1)
      end

      def status(process_message)
        @spinner.start
        @win.setpos(0, 3)
        @win.clrtoeol
        @win.addstr(process_message)
        @win.refresh
      end

      def state(state_message)
        clear
        @win.setpos(0, 2)
        @win.addstr('⢊')
        @win.setpos(0, 5)
        @win.clrtoeol
        @win.addstr(state_message)
        @win.refresh
      end

      def clear
        @spinner.stop
        @win.clear
        @win.refresh
      end

      def update_last_sync
        time = Time.iso8601(@main.engine.common_query.get_last_sync_time).getlocal.strftime('%b %d, %H:%M')
        offset = Curses.cols - time.length - 15
        @win.setpos(0, offset)
        @win.clrtoeol
        @win.addstr("⢊ Last Fetch: #{time} ")
        @win.refresh
      end
    end
  end
end
