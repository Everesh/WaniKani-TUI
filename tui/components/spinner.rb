# frozen_string_literal: true

module WaniKaniTUI
  module TUI
    # Creates a single char spinner for loadtimes e.g. api fetching, db init, review reporting
    class Spinner
      BRAILLE_FRAMES = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'].freeze

      def initialize(window, row, col)
        @window = window
        @row = row
        @col = col
        @frame = 0
        @should_stop = false

        @spinner_thread = Thread.new do
          until @should_stop
            render
            sleep(0.15)
          end
          clear
        end
      end

      def render
        @window.setpos(@row, @col)
        @window.addstr(BRAILLE_FRAMES[@frame])
        @window.refresh
        @frame = (@frame + 1) % BRAILLE_FRAMES.length
      end

      def clear
        @window.setpos(@row, @col)
        @window.addstr(' ')
        @window.refresh
      end

      def stop
        return unless @spinner_thread&.alive?

        @should_stop = true
        @spinner_thread.join
      end
    end
  end
end
