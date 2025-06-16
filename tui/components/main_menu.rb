# frozen_string_literal: true

# rubocop: disable all

require 'curses'

require_relative '../screens/title_screen'
require_relative '../screens/review_screen'
require_relative '../../lib/error/empty_buffer_error'

module WaniKaniTUI
  module TUI
    # Renders main menu dialog
    class MainMenu
      MENU_OPTIONS = %w[Review Lesson Report Fetch Home Exit].freeze

      attr_accessor :win

      def initialize(main)
        @main = main
        top_offset = [(Curses.lines / 5) * 3, Curses.lines - (MENU_OPTIONS.length * 2) - 4].min
        @win = Curses::Window.new((MENU_OPTIONS.length * 2) + 3, 20, top_offset, (Curses.cols - 20) / 2)
        @win.bkgd(Curses.color_pair(1))
      end

      def open
        @win.keypad(true)
        position = 0

        draw_menu(position)
        while (ch = @win.getch)
          case ch
          when 'w', 'k', Curses::Key::UP
            position -= 1
          when 's', 'j', Curses::Key::DOWN
            position += 1
          when Curses::Key::ENTER, 10, 13, 'l', Curses::Key::RIGHT
            change_window(MENU_OPTIONS[position])
            break
          when 27 # The escape key
            break
          end

          # Clamp position within valid range
          position = MENU_OPTIONS.length - 1 if position.negative?
          position = 0 if position >= MENU_OPTIONS.length

          draw_menu(position)
        end
        @win.keypad(false)
      rescue EmptyBufferError
        @main.status_line.state('No more pending items!')
        retry
      end

      private

      def draw_menu(active_index = nil)
        @win.clear
        @win.attrset(Curses::A_NORMAL)
        @win.box
        MENU_OPTIONS.each_with_index do |label, i|
          @win.attrset(i == active_index ? Curses::A_STANDOUT : Curses::A_NORMAL)
          count_available = case label
                            when 'Review'
                              @main.engine.common_query.count_available_reviews
                            when 'Lesson'
                              @main.engine.common_query.count_available_lessons
                            when 'Report'
                              @main.engine.common_query.count_pending_review_reports +
                              @main.engine.common_query.count_pending_lesson_reports
                            else
                              ''
                            end
          @win.setpos((1 + i) * 2, 1)
          @win.addstr("#{count_available} ".rjust(6, ' '))
          @win.addstr(label.ljust(12, ' '))
        end
        @win.refresh
      end

      def change_window(option)
        case option
        when 'Exit', nil
          raise Interrupt
        when 'Review'
          @main.screens['review'].open
        when 'Report'
          @main.status_line.status('Reporting to remote...')
          @main.engine.submit!
          @main.status_line.clear
          @main.status_line.status('Fetching from remote...')
          @main.engine.fetch!
          @main.status_line.clear
          @main.status_line.update_last_sync
          nil
        when 'Fetch'
          @main.status_line.status('Fetching from remote...')
          @main.engine.fetch!
          @main.status_line.clear
          @main.status_line.update_last_sync
        when 'Home'
          @main.screens['title'].open
          @main.overlays['main_menu'].open
        when 'Lesson'
          # TODO
          nil
        else
          raise ArgumentError, 'Option out of scope!'
        end
      end
    end
  end
end

# rubocop: enable all
