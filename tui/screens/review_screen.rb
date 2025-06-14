require 'curses'
require 'romkan'

require_relative '../../lib/error/attempting_already_passed_subject_error'

module WaniKaniTUI
  module TUI
    # The main Curses TUI application class.
    class ReviewScreen
      attr_accessor :win

      def initialize(main)
        @main = main
        @win = Curses::Window.new(Curses.lines - 1, Curses.cols, 0, 0)
        @win.bkgd(Curses.color_pair(1))
        @answer = ''
      end

      def open
        @subject = @main.engine.get_review
        mode = get_mode
        draw
        draw_task(mode)
        draw_answer
        while ch = @win.getch
          case ch
          when 27
            @main.overlays['main_menu'].open
          when 127, 8, 263
            @answer = @answer[0...-1] unless @answer.empty?
          when 10, 13
            correct_answer = if mode == 'meaning'
                               @main.engine.answer_review_meaning!(@answer)
                             else
                               @main.engine.answer_review_reading!(@answer)
                             end
            @answer = "#{correct_answer}" # TMP ANSWER DUMP
            open
          else
            @answer << ch
            @answer = @answer.to_kana if mode == 'reading'
          end
          draw
          draw_task(mode)
          draw_answer
        end
      end

      private

      def draw
        @win.keypad(true) # Refocuses keypad to avoid misscapture from main_menu
        @win.clear

        color = if @subject['object'] == 'radical'
                  3
                else
                  @subject['object'] == 'kanji' ? 4 : 5
                end
        @win.attron(Curses.color_pair(color))
        fill_main_bg
        draw_chars
        draw_meta
        @win.attroff(Curses.color_pair(color))
        @win.attron(Curses.color_pair(6))
        draw_progress_bar
        @win.attroff(Curses.color_pair(6))
        @win.setpos(Curses.lines - 2, 0)
        @win.addstr('_' * Curses.cols)
        @win.refresh
      end

      def draw_chars
        @win.attron(Curses::A_BOLD)

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
        @win.attroff(Curses::A_BOLD)
        @win.setpos(Curses.lines - 8, 0)
        @win.addstr('_' * Curses.cols)
      end

      def draw_progress_bar
        @win.setpos(0, 0)
        last_col = (@main.engine.progress_statuss_reviews * Curses.cols).floor
        @win.addstr('█' * last_col)
        @win.addstr(' ' * (Curses.cols - last_col))
      end

      def draw_meta
        progress_string = "#{@main.engine.common_query.count_pending_review_reports}/#{@main.engine.common_query.count_available_reviews}"
        @win.setpos(2, Curses.cols - 3 - progress_string.length)
        @win.addstr(progress_string)

        chars = @subject[:subject]['characters']
        chars = @subject[:subject]['slug'] if chars.nil?
        @win.setpos(2, 3)
        @win.addstr(chars)
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
        @win.attron(Curses.color_pair(2)) if mode == 'meaning'
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
        @win.attroff(Curses.color_pair(2)) if mode == 'meaning'
      end

      def fill_main_bg
        line = ' ' * Curses.cols
        (1...Curses.lines - 8).each do |i|
          @win.setpos(i, 0)
          @win.addstr(line)
        end
      end

      def draw_answer
        @win.setpos(Curses.lines - 3, 0)
        @win.addstr(' ' * Curses.cols)
        @win.setpos(Curses.lines - 3, (Curses.cols - @answer.length) / 2)
        @win.addstr(@answer)
      end
    end
  end
end
