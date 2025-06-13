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

        draw_chars
        draw_answer_box
        draw_progress_bar

        @win.refresh
      end

      def draw_chars
        chars = @main.engine.get_review[:subject]['characters']
        chars = @main.engine.get_review[:subject]['slug'] if chars.nil?
        zero_gap = @main.preferences['no_line_spacing_correction']

        height = [Curses.lines / 2, @main.preferences['max_char_height']].min
        max_width = (Curses.cols * 2) / 3
        subject = @main.cjk_renderer.get_braille(chars, height, zero_gap: zero_gap)
        if subject.first.length > max_width
          subject = @main.cjk_renderer.get_braille(chars, max_width, zero_gap: zero_gap, size_as_width: true)
        end

        top_offset = ((Curses.lines - 8 - subject.length) / 2) + 1
        subject.each_with_index do |row, i|
          @win.setpos(top_offset + i, ((Curses.cols - row.length) / 2) + 1)
          @win.addstr(row.join(''))
        end
      end

      def draw_answer_box
        @win.setpos(Curses.lines - 8, 0)
        @win.addstr('_' * Curses.cols)

        @win.setpos(Curses.lines - 5, 0)
        @win.addstr('_' * Curses.cols)

        @win.setpos(Curses.lines - 2, 0)
        @win.addstr('_' * Curses.cols)
      end

      def draw_progress_bar
        @win.setpos(0, 0)
        last_col = (@main.engine.progress_statuss_reviews * Curses.cols).floor
        @win.addstr('█' * last_col)
        @win.setpos(0, last_col)
        @win.addstr('░' * (Curses.cols - last_col))

        progress_string = "#{@main.engine.common_query.count_pending_review_reports}/#{@main.engine.common_query.count_available_reviews}"
        @win.setpos(1, Curses.cols - 1 - progress_string.length)
        @win.addstr(progress_string)
      end
    end
  end
end
