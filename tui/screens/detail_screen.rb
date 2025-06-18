require 'curses'

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

      def open(subject, answer, mode)
        # Both arrow keys and ESC are detected as 27 without keypad, this somewhat fixes it
        @win.keypad(true)
        draw(subject, answer, mode)
        while ch = @win.getch
          case ch
          when 27
            @main.open_menu
            draw(subject, answer, mode)
          when 410
            draw(subject, answer, mode)
          else
            break
          end
        end
      ensure
        @win.keypad(true)
      end

      private

      def draw(subject, answer, mode)
        @win.clear
        draw_progress_bar
        draw_compact_main(subject)
        draw_dialog(subject, answer, mode)
        draw_details(subject)
        @win.refresh
        draw_mnemonics(subject)
      end

      def draw_compact_main(subject)
        color = if subject[:subject]['object'] == 'radical'
                  3
                else
                  subject[:subject]['object'] == 'kanji' ? 4 : 5
                end
        @win.attron(Curses.color_pair(color))

        (1..3).each do |i|
          @win.setpos(i, 0)
          @win.addstr(' ' * Curses.cols)
        end

        chars = subject[:subject]['characters'] || subject[:subject]['slug']
        @win.setpos(2, 3)
        @win.addstr(chars)

        @win.attron(Curses::A_BOLD)
        @win.setpos(2, (Curses.cols - (chars.length * 2)) / 2)
        @win.addstr(chars)
        @win.attroff(Curses::A_BOLD)

        progress_string = "#{@main.engine.common_query.count_pending_review_reports}/#{@main.engine.common_query.count_available_reviews}"
        @win.setpos(2, Curses.cols - 3 - progress_string.length)
        @win.addstr(progress_string)

        @win.setpos(3, 0)
        @win.addstr('_' * Curses.cols)
        @win.attroff(Curses.color_pair(color))
      end

      def draw_progress_bar
        @win.attron(Curses.color_pair(6))
        @win.setpos(0, 0)
        last_col = (@main.engine.progress_statuss_reviews * Curses.cols).floor
        @win.addstr('█' * last_col)
        @win.addstr(' ' * (Curses.cols - last_col))
        @win.attroff(Curses.color_pair(6))
      end

      def draw_dialog(subject, answer, mode)
        @win.attron(Curses.color_pair(2)) if mode == 'meaning'

        (4..6).each do |i|
          @win.setpos(i, 0)
          @win.addstr(' ' * Curses.cols)
        end

        object = "#{subject[:subject]['object'].capitalize} "
        @win.setpos(5, (Curses.cols - object.length - 1 - mode.length) / 2)
        @win.addstr(object)
        @win.attron(Curses::A_BOLD)
        @win.addstr(mode.capitalize)
        @win.attroff(Curses::A_BOLD)

        @win.setpos(6, 0)
        @win.addstr('_' * Curses.cols)

        @win.attroff(Curses.color_pair(2)) if mode == 'meaning'
        @win.attron(Curses.color_pair(7))

        (7..9).each do |i|
          @win.setpos(i, 0)
          @win.addstr(' ' * Curses.cols)
        end

        real_string_width = answer.each_char.sum { |ch| ch.ord.between?(0x2E80, 0x9FFF) ? 2 : 1 }
        @win.setpos(8, (Curses.cols - real_string_width) / 2)
        @win.addstr(answer)

        @win.setpos(9, 0)
        @win.addstr('_' * Curses.cols)

        @win.attroff(Curses.color_pair(7))
      end

      def draw_details(subject)
        @win.setpos(11, 3)
        @win.addstr('Meaning:')

        @win.attron(Curses.color_pair(8))
        @win.attron(Curses::A_BOLD)
        meanings = subject[:meanings].filter { |meaning| meaning['accepted'] == 1 }.map { |meaning| meaning['meaning'] }
        @win.setpos(11, 12)
        @win.addstr(meanings.join(', '))
        @win.attroff(Curses::A_BOLD)
        @win.attroff(Curses.color_pair(8))
        meanings_not_accepted = subject[:meanings].filter do |meaning|
          meaning['accepted'] == 0
        end.map { |meaning| meaning['meaning'] }
        @win.addstr(', ') if !meanings.empty? && !meanings_not_accepted.empty?
        @win.addstr(meanings_not_accepted.join(', '))

        return if subject[:readings].empty?

        @win.setpos(13, 3)
        @win.addstr('Reading:')

        @win.attron(Curses.color_pair(8))
        @win.attron(Curses::A_BOLD)
        readings = subject[:readings].filter do |reading|
          reading['accepted'] == 1
        end.map { |reading| reading['reading'] }
        @win.setpos(13, 12)
        @win.addstr(readings.join(', '))
        @win.attroff(Curses::A_BOLD)
        @win.attroff(Curses.color_pair(8))
        readings_not_accepted = subject[:readings].filter do |reading|
          reading['accepted'] == 0
        end.map { |readings| readings['reading'] }
        @win.addstr(', ') if !readings.empty? && !readings_not_accepted.empty?
        @win.addstr(readings_not_accepted.join(', '))
      end

      def draw_mnemonics(subject)
        # I am sorry dear God for this unholy mess I have brought uppon this land
        # Gomena sorry dayo 人(_ _*)
        @win.setpos(15, 3)
        @win.addstr('Meaning mnemonic:')
        window_mnemonic_meaning = Curses::Window.new((Curses.lines - 22) / 2, Curses.cols - 10, 17, 5)
        window_mnemonic_meaning.clear
        window_mnemonic_meaning.bkgd(Curses.color_pair(1))
        window_mnemonic_meaning.setpos(0, 0)
        meaning_max_width = window_mnemonic_meaning.maxx
        meaning_x = window_mnemonic_meaning.cury
        meaning_y = window_mnemonic_meaning.curx

        subject[:subject]['mnemonic_meaning']
          .split(%r{(<\w+>.*?</\w+>)})
          .map do |part|
            if part =~ %r{<(\w+)>(.*?)</\1>}
              [Regexp.last_match(1), Regexp.last_match(2)]
            else
              ['', part]
            end
          end
          .each do |tag, text|
            color_pair = case tag
                         when 'radical' then 3
                         when 'kanji' then 4
                         when 'vocabulary' then 5
                         when 'reading' then 2
                         when 'meaning' then 2
                         end

            window_mnemonic_meaning.attron(Curses.color_pair(color_pair)) if color_pair

            text.scan(/\s*\S+\s*|\n/).each do |word|
              if meaning_x + word.length >= meaning_max_width || word == "\n"
                meaning_y += 1
                meaning_x = 0
                window_mnemonic_meaning.setpos(meaning_y, meaning_x)
              end

              window_mnemonic_meaning.addstr(word)
              meaning_x += word.length
            end

            window_mnemonic_meaning.attroff(Curses.color_pair(color_pair)) if color_pair
          end

        window_mnemonic_meaning.refresh
        window_mnemonic_meaning.close

        return unless subject[:subject]['mnemonic_reading']

        readmnem_offset = ((Curses.lines - 22) / 2) + 18
        @win.setpos(readmnem_offset, 3)
        @win.addstr('Reading mnemonic:')
        window_mnemonic_reading = Curses::Window.new((Curses.lines - 22) / 2, Curses.cols - 10, readmnem_offset + 2, 5)
        window_mnemonic_reading.clear
        window_mnemonic_reading.bkgd(Curses.color_pair(1))
        window_mnemonic_reading.setpos(0, 0)
        reading_max_width = window_mnemonic_reading.maxx
        reading_x = window_mnemonic_reading.cury
        reading_y = window_mnemonic_reading.curx

        subject[:subject]['mnemonic_reading']
          .split(%r{(<\w+>.*?</\w+>)})
          .map do |part|
            if part =~ %r{<(\w+)>(.*?)</\1>}
              [Regexp.last_match(1), Regexp.last_match(2)]
            else
              ['', part]
            end
          end
          .each do |tag, text|
            color_pair = case tag
                         when 'radical' then 3
                         when 'kanji' then 4
                         when 'vocabulary' then 5
                         when 'reading' then 2
                         when 'meaning' then 2
                         end

            window_mnemonic_reading.attron(Curses.color_pair(color_pair)) if color_pair

            text.scan(/\s*\S+\s*|\n/).each do |word|
              if reading_x + word.length >= reading_max_width || word == "\n"
                reading_y += 1
                reading_x = 0
                window_mnemonic_reading.setpos(reading_y, reading_x)
              end

              window_mnemonic_reading.addstr(word)
              reading_x += word.length
            end

            window_mnemonic_reading.attroff(Curses.color_pair(color_pair)) if color_pair
          end

        window_mnemonic_reading.refresh
        window_mnemonic_reading.close
      end
    end
  end
end
