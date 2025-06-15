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
        draw(subject, answer, mode)
        @win.getch
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

        chars = subject[:subject]['characters']
        chars = subject[:subject]['slug'] if chars.nil?
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
        @win.setpos(0, 0)
        last_col = (@main.engine.progress_statuss_reviews * Curses.cols).floor
        @win.addstr('█' * last_col)
        @win.addstr(' ' * (Curses.cols - last_col))
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
        @win.setpos(15, 3)
        @win.addstr('Meaning mnemonic:')
        window_mnemonic_meaning = Curses::Window.new((Curses.lines - 19) / 2, Curses.cols - 10, 17, 5)
        window_mnemonic_meaning.bkgd(Curses.color_pair(1))
        window_mnemonic_meaning.setpos(0, 0)
        subject[:subject]['mnemonic_meaning'].split(%r{(<\w+>.*?</\w+>)})
                                             .map do |part|
          if part =~ %r{<(\w+)>(.*?)</\1>}
            [::Regexp.last_match(1),
             ::Regexp.last_match(2)]
          else
            [
              '', part
            ]
          end
        end
                                             .each do |segment|
          case segment.first
          when 'radical' then window_mnemonic_meaning.attron(Curses.color_pair(3))
          when 'kanji' then window_mnemonic_meaning.attron(Curses.color_pair(4))
          when 'vocabulary' then window_mnemonic_meaning.attron(Curses.color_pair(5))
          end
          window_mnemonic_meaning.addstr(segment.last)
          case segment.first
          when 'radical' then window_mnemonic_meaning.attroff(Curses.color_pair(3))
          when 'kanji' then window_mnemonic_meaning.attroff(Curses.color_pair(4))
          when 'vocabulary' then window_mnemonic_meaning.attroff(Curses.color_pair(5))
          end
        end
        window_mnemonic_meaning.refresh
        window_mnemonic_meaning.close

        return unless subject[:subject]['mnemonic_reading']

        readmnem_offset = ((Curses.lines - 19) / 2) + 17
        @win.setpos(readmnem_offset, 3)
        @win.addstr('Reading mnemonic:')
        window_mnemonic_reading = Curses::Window.new((Curses.lines - 19) / 2, Curses.cols - 10, readmnem_offset + 2, 5)
        window_mnemonic_reading.bkgd(Curses.color_pair(1))
        window_mnemonic_reading.setpos(0, 0)
        subject[:subject]['mnemonic_reading'].split(%r{(<\w+>.*?</\w+>)})
                                             .map do |part|
          if part =~ %r{<(\w+)>(.*?)</\1>}
            [::Regexp.last_match(1),
             ::Regexp.last_match(2)]
          else
            [
              '', part
            ]
          end
        end
                                             .each do |segment|
          case segment.first
          when 'radical' then window_mnemonic_reading.attron(Curses.color_pair(3))
          when 'kanji' then window_mnemonic_reading.attron(Curses.color_pair(4))
          when 'vocabulary' then window_mnemonic_reading.attron(Curses.color_pair(5))
          end
          window_mnemonic_reading.addstr(segment.last)
          case segment.first
          when 'radical' then window_mnemonic_reading.attroff(Curses.color_pair(3))
          when 'kanji' then window_mnemonic_reading.attroff(Curses.color_pair(4))
          when 'vocabulary' then window_mnemonic_reading.attroff(Curses.color_pair(5))
          end
        end
        window_mnemonic_reading.refresh
        window_mnemonic_reading.close
      end
    end
  end
end
