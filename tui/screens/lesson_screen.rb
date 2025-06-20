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
      end

      def open
        # Both arrow keys and ESC are detected as 27 without keypad, this somewhat fixes it
        @win.keypad(true)
        @should_exit = false
        @mode = 'components'
        draw(@mode)
        while ch = @win.getch
          case ch
          when 27
            @main.open_menu(source: 'lesson')
            if @should_exit
              @main.screens[caller].close if caller
              return
            end

            draw(@mode)
          when 410
            draw(@mode)
            @main.status_line.resize
          when Curses::KEY_LEFT, 'a', 'h'
            @mode = 'components'
            @main.engine.lesson_unsee! rescue NotYetSeenError
            draw(@mode)
          else
            break unless @main.engine.get_lesson[:lesson][:seen].zero?

            @mode = @mode == 'components' ? 'meaning' : @mode == 'meaning' ? 'reading' : 'passed'
            if @mode == 'passed'
              @main.engine.lesson_seen!
              @mode = 'components'
            end
            draw(@mode)
          end
        end
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
        # draw_progress_bar
        draw_compact_main
        case mode
        when 'components' then draw_components
        when 'meaning' then draw_meaning
        when 'reading' then draw_reading
        when 'passed' then draw_task
        end
        # draw_components
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

        main_height = [(Curses.lines - 2) / 3, 3].max
        main_height.times do |i|
          @win.setpos(1+i, 0)
          @win.addstr(' ' * Curses.cols)
        end

        chars = lesson[:subject]['characters'] || lesson[:subject]['slug']
        @win.setpos(2, 3)
        @win.addstr(chars)

        @win.attron(Curses::A_BOLD)
        if main_height > 7
          zero_gap = @main.preferences['no_line_spacing_correction']
          subject = @main.cjk_renderer.get_braille(chars, main_height - 2, zero_gap: zero_gap)
          max_width = (Curses.cols * 2) / 3
          if subject.first.length > max_width
            subject = @main.cjk_renderer.get_braille(chars, max_width, zero_gap: zero_gap, size_as_width: true)
          end

          subject.each_with_index do |row, i|
            @win.setpos(2+i, ((Curses.cols - row.length) / 2) + 1)
            @win.addstr(row.join(''))
          end
        else
          @win.setpos(((main_height-2) / 2) + 2, ((Curses.cols - chars.length) / 2) + 1)
          @win.addstr(chars)
        end
        @win.attroff(Curses::A_BOLD)

        @win.attroff(Curses.color_pair(color))
      end

      def draw_components
        top_offset = ((Curses.lines - 2 ) / 3) + 1
        height = 2 * ((Curses.lines - 2 ) / 3)

        @win.setpos(top_offset + 1, 3)
        @win.addstr('Components:')
      end

      def draw_meaning
        top_offset = ((Curses.lines - 2 ) / 3) + 1
        height = 2 * ((Curses.lines - 2 ) / 3)

        @win.setpos(top_offset + 1, 3)
        @win.addstr('Meaning:')
      end

      def draw_reading
        top_offset = ((Curses.lines - 2 ) / 3) + 1
        height = 2 * ((Curses.lines - 2 ) / 3)

        @win.setpos(top_offset + 1, 3)
        @win.addstr('Reading:')
      end
    end
  end
end
