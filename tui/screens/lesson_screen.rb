require 'curses'

require_relative '../../lib/error/not_yet_seen_error'

module WaniKaniTUI
  module TUI
    # Detail screen of a subject showing components
    class LessonScreen
      attr_accessor :win

      def initialize(main)
        @main = main
        @win = Curses::Window.new(Curses.lines - 1, Curses.cols, 0, 0)
        @win.bkgd(Curses.color_pair(1))
        @should_exit = false
        @mode = 'components'

        @seen = 0
        @finished = 0
      end

      def open
        # Both arrow keys and ESC are detected as 27 without keypad, this somewhat fixes it
        @win.keypad(true)
        @should_exit = false
        @mode = %w[kanji vocabulary].include?(@main.engine.get_lesson[:subject]['object']) ? 'components' : 'meaning'
        draw(@mode)
        while ch = @win.getch
          case ch
          when 27
            @main.open_menu(source: 'lesson')
            return if @should_exit

            draw(@mode)
          when 410
            draw(@mode)
            @main.status_line.resize
          when Curses::KEY_LEFT, 'a', 'h'
            @mode = 'components'
            begin
              @seen -= 1
              @main.engine.lesson_unsee!
            rescue NotYetSeenError
              @seen += 1
            end
            draw(@mode)
          else
            break unless @main.engine.get_lesson[:lesson][:seen].zero?

            @mode = if @mode == 'components'
                      'meaning'
                    elsif @mode == 'meaning' && @main.engine.get_lesson[:subject]['object'] != 'radical'
                      'reading'
                    else
                      'passed'
                    end
            if @mode == 'passed'
              @main.engine.lesson_seen!
              @mode = 'components'
              @seen += 1
            end
            draw(@mode)
          end
        end

        # TODO: - review logic
      ensure
        @win.keypad(false)
      end

      def close
        @should_exit = true
      end

      def resize
        draw(@mode)
      end

      private

      def draw(mode)
        @win.clear
        draw_progress_bar
        draw_compact_main
        case mode
        when 'components' then draw_components
        when 'meaning' then draw_meaning
        when 'reading' then draw_reading
        when 'passed' then draw_task
        end
        @win.refresh
      end

      def draw_compact_main
        lesson = @main.engine.get_lesson
        color = if lesson[:subject]['object'] == 'radical'
                  3
                else
                  lesson[:subject]['object'] == 'kanji' ? 4 : 5
                end
        @win.attron(Curses.color_pair(color))

        main_height = [(Curses.lines - 2) / 2, 3].max
        main_height.times do |i|
          @win.setpos(1 + i, 0)
          @win.addstr(' ' * Curses.cols)
        end

        chars = lesson[:subject]['characters'] || lesson[:subject]['slug']
        @win.setpos(2, 3)
        @win.addstr(chars)

        progress = "Learned: #{@seen}/#{@main.engine.lesson_buffer_size}"
        @win.setpos(2, Curses.cols - (progress.length + 2))
        @win.addstr(progress)
        finished = "Passed: #{@finished}/#{@main.engine.lesson_buffer_size}"
        @win.setpos(3, Curses.cols - (finished.length + 2))
        @win.addstr(finished)

        @win.attron(Curses::A_BOLD)
        if main_height > 7
          zero_gap = @main.preferences['no_line_spacing_correction']
          height = [main_height - 2, @main.preferences['max_char_height'] || main_height - 2].min
          subject = @main.cjk_renderer.get_braille(chars, height, zero_gap: zero_gap)
          max_width = (Curses.cols * 2) / 3
          if subject.first.length > max_width
            subject = @main.cjk_renderer.get_braille(chars, max_width, zero_gap: zero_gap, size_as_width: true)
          end

          top_offset = ((main_height - subject.length) / 2) + 1
          subject.each_with_index do |row, i|
            @win.setpos(top_offset + i, ((Curses.cols - row.length) / 2) + 1)
            @win.addstr(row.join(''))
          end
        else
          @win.setpos(((main_height - 2) / 2) + 2, ((Curses.cols - chars.length) / 2) + 1)
          @win.addstr(chars)
        end
        @win.attroff(Curses::A_BOLD)

        @win.attroff(Curses.color_pair(color))
      end

      def draw_progress_bar
        @win.attron(Curses.color_pair(6))
        @win.setpos(0, 0)
        last_col = ((@seen.to_f / @main.engine.lesson_buffer_size) * Curses.cols).floor
        @win.addstr('░' * last_col)
        @win.addstr(' ' * (Curses.cols - last_col))
        last_col_finished = ((@finished.to_f / @main.engine.lesson_buffer_size) * Curses.cols).floor
        @win.addstr('█' * last_col_finished)
        @win.attroff(Curses.color_pair(6))
      end

      def draw_components
        top_offset = ((Curses.lines - 2) / 2) + 1
        height = (Curses.lines - 2) / 2

        @win.setpos(top_offset + 1, 3)
        @win.addstr('Components:')

        lesson = @main.engine.get_lesson
        if lesson[:components].length.zero?
          @mode = 'meaning'
          return draw(@mode)
        end
        gap = if lesson[:components].length == 1
                0
              else
                (((Curses.cols * 3) / 5) - lesson[:components].length) / (lesson[:components].length - 1)
              end
        lesson[:components].each_with_index do |component, i|
          char = component['characters'] || component['slug']
          meaning = @main.engine.common_query.get_meanings_by_id_as_hash(component['id']).first['meaning']
          @win.setpos(top_offset + (height / 2) + 2, (Curses.cols / 5) + (i * gap) - (meaning.length / 2) + 1)
          @win.addstr(meaning)
          @win.attron(Curses.color_pair(component['object'] == 'radical' ? 3 : 4))
          @win.setpos(top_offset + (height / 2), (Curses.cols / 5) + (i * gap) - 1)
          @win.addstr('    ')
          @win.setpos(top_offset + (height / 2) - 1, (Curses.cols / 5) + (i * gap) - 1)
          @win.addstr('    ')
          @win.setpos(top_offset + (height / 2) - 1, (Curses.cols / 5) + (i * gap))
          @win.addstr(char)
          @win.setpos(top_offset + (height / 2) - 2, (Curses.cols / 5) + (i * gap) - 1)
          @win.addstr('    ')
          @win.attroff(Curses.color_pair(component['object'] == 'radical' ? 3 : 4))
        end
      end

      def draw_meaning
        top_offset = ((Curses.lines - 2) / 2) + 1
        height = 2 * ((Curses.lines - 2) / 2)

        @win.setpos(top_offset + 1, 3)
        @win.addstr('Meaning:')

        # TODO
      end

      def draw_reading
        top_offset = ((Curses.lines - 2) / 2) + 1
        height = 2 * ((Curses.lines - 2) / 2)

        @win.setpos(top_offset + 1, 3)
        @win.addstr('Reading:')

        # TODO
      end
    end
  end
end
