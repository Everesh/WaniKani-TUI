require 'curses'
require 'romkan'

require_relative '../../lib/error/not_yet_seen_error'
require_relative '../../lib/error/attempting_already_passed_subject_error'

module WaniKaniTUI
  module TUI
    # Detail screen of a subject showing components
    class LessonScreen
      attr_accessor :win
      attr_reader :seen, :finished

      def initialize(main)
        @main = main
        @win = Curses::Window.new(Curses.lines - 1, Curses.cols, 0, 0)
        @win.bkgd(Curses.color_pair(1))
        @should_exit = false
        @mode = 'components'

        @answer = ''
        @mode_review = 'meaning'

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
            break unless @main.engine.get_lesson[:lesson][:seen].zero?
          end
        end
        open_review
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
        return unless %w[meaning reading].include?(@mode)

        mnem = @main.engine.get_lesson[:subject]["mnemonic_#{@mode}"]
        top_offset = ((Curses.lines - 2) / 2) + 6
        height = ((Curses.lines - 2) / 2) - 5
        draw_mnemonic(mnem, top_offset, height)
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
        @win.setpos(0, 0)
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
        lesson = @main.engine.get_lesson
        top_offset = ((Curses.lines - 2) / 2) + 1

        @win.setpos(top_offset + 1, 3)
        @win.addstr('Meaning:')

        @win.attron(Curses.color_pair(8))
        @win.attron(Curses::A_BOLD)
        meanings = lesson[:meanings].filter { |meaning| meaning['accepted'] == 1 }.map { |meaning| meaning['meaning'] }
        @win.setpos(top_offset + 1, 12)
        @win.addstr(meanings.join(', '))
        @win.attroff(Curses::A_BOLD)
        @win.attroff(Curses.color_pair(8))

        meanings_not_accepted = lesson[:meanings].filter do |meaning|
          meaning['accepted'] == 0
        end.map { |meaning| meaning['meaning'] }
        @win.addstr(', ') if !meanings.empty? && !meanings_not_accepted.empty?
        @win.addstr(meanings_not_accepted.join(', '))

        @win.setpos(top_offset + 3, 3)
        @win.addstr('Meaning mnemonic:')
      end

      def draw_reading
        lesson = @main.engine.get_lesson
        top_offset = ((Curses.lines - 2) / 2) + 1

        @win.setpos(top_offset + 1, 3)
        @win.addstr('Reading:')

        @win.attron(Curses.color_pair(8))
        @win.attron(Curses::A_BOLD)
        readings = lesson[:readings].filter do |reading|
          reading['accepted'] == 1
        end.map { |reading| reading['reading'] }
        @win.setpos(top_offset + 1, 12)
        @win.addstr(readings.join(', '))
        @win.attroff(Curses::A_BOLD)
        @win.attroff(Curses.color_pair(8))

        readings_not_accepted = lesson[:readings].filter do |reading|
          reading['accepted'] == 0
        end.map { |reading| reading['reading'] }
        @win.addstr(', ') if !readings.empty? && !readings_not_accepted.empty?
        @win.addstr(readings_not_accepted.join(', '))

        @win.setpos(top_offset + 3, 3)
        @win.addstr('Reading mnemonic:')
      end

      def draw_mnemonic(mnemonic, top_offset, height)
        return if height < 1

        win_mnem = Curses::Window.new(height, Curses.cols - 10, top_offset, 5)
        win_mnem.clear
        win_mnem.bkgd(Curses.color_pair(1))
        win_mnem.setpos(0, 0)
        meaning_max_width = win_mnem.maxx
        meaning_x = win_mnem.cury
        meaning_y = win_mnem.curx

        mnemonic&.split(%r{(<\w+>.*?</\w+>)})
                &.map do |part|
                  if part =~ %r{<(\w+)>(.*?)</\1>}
                    [Regexp.last_match(1), Regexp.last_match(2)]
                  else
                    ['', part]
                  end
                end
                &.each do |tag, text|
          color_pair = case tag
                       when 'radical' then 3
                       when 'kanji' then 4
                       when 'vocabulary' then 5
                       when 'reading' then 2
                       when 'meaning' then 2
                       end

          win_mnem.attron(Curses.color_pair(color_pair)) if color_pair

          text.scan(/\s*\S+\s*|\n/).each do |word|
            if meaning_x + word.length >= meaning_max_width || word == "\n"
              meaning_y += 1
              meaning_x = 0
              win_mnem.setpos(meaning_y, meaning_x)
            end

            win_mnem.addstr(word)
            meaning_x += word.length
          end

          win_mnem.attroff(Curses.color_pair(color_pair)) if color_pair
        end

        win_mnem.refresh
        win_mnem.close
      end

      def open_review
        loop do
          lesson = @main.engine.get_lesson
          @mode_review = get_review_mode(lesson)
          draw_review
          draw_answer
          draw_progress_bar

          while ch = @win.getch
            case ch
            when 27
              @main.open_menu(source: 'lesson')

              return if @should_exit
            when 127, 8, 263
              @answer = @answer[0...-1] unless @answer.empty?
            when 10, 13
              unless (@mode_review == 'meaning' && @answer.match?(/\A[a-zA-Z0-9 ]+\z/)) ||
                     (@mode_review == 'reading' && @answer.match?(/\A[\u3040-\u309F\u30A0-\u30FF0-9]+\z/))
                @main.status_line.state("There is probably a typo in: \"#{@answer}\", only #{@mode_review == 'meaning' ? '[a-z][A-Z][0-9]' : 'kana or [0-9]'} accepted!")
                next
              end
              @main.status_line.clear

              about_to_finish = lesson[:lesson][:meaning_passed] == 1 || lesson[:lesson][:reading_passed] == 1
              correct_answer = if @mode_review == 'meaning'
                                 @main.engine.answer_lesson_meaning!(@answer)
                               else
                                 @main.engine.answer_lesson_reading!(@answer.to_kana)
                               end
              if correct_answer
                @finished += 1 if about_to_finish
                if @main.engine.lesson_buffer_size <= @finished

                  # reset state before exit
                  @answer = ''
                  @mode_review = 'meaning'
                  @seen = 0
                  @finished = 0
                  return
                end
              else
                @main.screens['detail'].open(lesson, @answer, @mode_review, caller: 'lesson')
              end
              return if @should_exit

              @answer = ''
              break
            when 410
              @main.status_line.resize
            when 16 # ctrl + p
              about_to_finish = lesson[:lesson][:meaning_passed] == 1 || lesson[:lesson][:reading_passed] == 1
              if @mode_review == 'meaning'
                @main.engine.pass_lesson_meaning!
              else
                @main.engine.pass_lesson_reading!
              end
              @finished += 1 if about_to_finish
              if @main.engine.lesson_buffer_size <= @finished

                # reset state before exit
                @answer = ''
                @mode_review = 'meaning'
                @seen = 0
                @finished = 0
                return
              end
              break
            else
              @answer << ch
              if @mode_review == 'reading' && (@answer[-1] != 'n' || (@answer.length > 1 && @answer[-2] == 'n'))
                @answer = @answer.to_kana
              end
            end
            draw_review
            draw_answer
            draw_progress_bar
          end
        end
      end

      def draw_review
        lesson = @main.engine.get_lesson
        color = if lesson[:subject]['object'] == 'radical'
                  3
                else
                  lesson[:subject]['object'] == 'kanji' ? 4 : 5
                end
        @win.attron(Curses.color_pair(color))

        height = Curses.lines - 7
        height.times do |i|
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
        if height > 7
          zero_gap = @main.preferences['no_line_spacing_correction']
          char_height = [height - 2, @main.preferences['max_char_height'] || height - 6].min
          subject = @main.cjk_renderer.get_braille(chars, char_height, zero_gap: zero_gap)
          max_width = (Curses.cols * 2) / 3
          if subject.first.length > max_width
            subject = @main.cjk_renderer.get_braille(chars, max_width, zero_gap: zero_gap, size_as_width: true)
          end

          top_offset = ((height - subject.length) / 2) + 1
          subject.each_with_index do |row, i|
            @win.setpos(top_offset + i, ((Curses.cols - row.length) / 2) + 1)
            @win.addstr(row.join(''))
          end
        else
          @win.setpos(((height - 2) / 2) + 2, ((Curses.cols - chars.length) / 2) + 1)
          @win.addstr(chars)
        end
        @win.attroff(Curses::A_BOLD)
        @win.setpos(height + 1, 0)
        @win.addstr('_' * Curses.cols)

        @win.attroff(Curses.color_pair(color))
        draw_bottom_dialog(height, lesson)
      end

      def draw_bottom_dialog(top_offset, lesson)
        object = "#{lesson[:subject]['object'].capitalize} "
        @win.attron(Curses.color_pair(2)) if @mode_review == 'meaning'
        @win.setpos(top_offset, 0)
        @win.addstr(' ' * Curses.cols)
        @win.setpos(top_offset + 1, 0)
        @win.addstr(' ' * Curses.cols)
        @win.setpos(top_offset + 1, (Curses.cols - object.length - 1 - @mode_review.length) / 2)
        @win.addstr(object)
        @win.attron(Curses::A_BOLD)
        @win.addstr(@mode_review.capitalize)
        @win.attroff(Curses::A_BOLD)
        @win.setpos(top_offset + 2, 0)
        @win.addstr('_' * Curses.cols)
        @win.attroff(Curses.color_pair(2)) if @mode_review == 'meaning'
      end

      def get_review_mode(lesson)
        options = []
        options << 'meaning' if lesson[:lesson][:meaning_passed].zero?
        options << 'reading' if lesson[:lesson][:reading_passed].zero?
        raise AttemptingAlreadyPassedSubjectError if options.empty?

        options.sample
      end

      def draw_answer
        (2..4).each do |i|
          @win.setpos(Curses.lines - i, 0)
          @win.addstr(' ' * Curses.cols)
        end

        real_string_width = @answer.each_char.sum { |ch| ch.ord.between?(0x2E80, 0x9FFF) ? 2 : 1 }
        @win.setpos(Curses.lines - 3, (Curses.cols - real_string_width) / 2)
        @win.addstr(@answer)

        @win.setpos(Curses.lines - 2, 0)
        @win.addstr('_' * Curses.cols)
      end
    end
  end
end
