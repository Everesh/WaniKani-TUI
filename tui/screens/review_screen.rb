require 'curses'

require_relative '../../lib/error/attempting_already_passed_subject_error'

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
        @subject = @main.engine.get_review
        draw
        mode = get_mode
        draw_task(mode)
        while ch = @win.getch
          case ch
          when 27
            @main.overlays['main_menu'].open
          else
            # TODO
          end
          draw
          draw_task(mode)
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
        chars = @subject[:subject]['characters']
        chars = @subject[:subject]['slug'] if chars.nil?
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

        chars = @subject[:subject]['characters']
        chars = @subject[:subject]['slug'] if chars.nil?
        @win.setpos(2, 3)
        @win.addstr(chars)

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
        @win.setpos(2, Curses.cols - 3 - progress_string.length)
        @win.addstr(progress_string)
      end

      def get_mode
        options = []
        options << 'meaning' unless @subject[:review]['meaning_passsed']
        options << 'reading' unless @subject[:review]['reading_passsed']
        raise AttemptingAlreadyPassedSubjectError if options.empty?

        options.sample
      end

      def draw_task(mode)
        object = "#{@subject[:subject]['object'].capitalize} "
        @win.attron(Curses::A_REVERSE) if mode == 'meaning'
        @win.setpos(Curses.lines - 7, 0)
        @win.addstr(' ' * Curses.cols)
        @win.setpos(Curses.lines - 6, 0)
        @win.addstr(' ' * Curses.cols)
        @win.setpos(Curses.lines - 6, (Curses.cols - object.length - 1 - mode.length) / 2)
        @win.addstr(object)
        @win.attron(Curses::A_BOLD)
        @win.addstr(mode.capitalize)
        @win.attroff(Curses::A_BOLD)
        @win.setpos(Curses.lines - 5, 0)
        @win.addstr('_' * Curses.cols)
        @win.attroff(Curses::A_REVERSE) if mode == 'meaning'
      end
    end
  end
end
