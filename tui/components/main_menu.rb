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
      def self.open(main, menu_options)
        top_offset = [(Curses.lines / 5) * 3, Curses.lines - (menu_options.length * 2) - 4].min
        win = Curses::Window.new((menu_options.length * 2) + 3, 20, top_offset, (Curses.cols - 20) / 2)
        win.bkgd(Curses.color_pair(1))
        win.keypad(true)
        position = 0

        draw_menu(win, menu_options, main, position)
        while (ch = win.getch)
          case ch
          when 'w', 'k', Curses::Key::UP
            position -= 1
          when 's', 'j', Curses::Key::DOWN
            position += 1
          when Curses::Key::ENTER, 10, 13, 'l', Curses::Key::RIGHT
            return menu_options[position]
          when 410
            return 'Resize'
          when 27 # The escape key
            break
          end

          # Clamp position within valid range
          position = menu_options.length - 1 if position.negative?
          position = 0 if position >= menu_options.length

          draw_menu(win, menu_options, main, position)
        end
      rescue EmptyBufferError
        main.status_line.state('No more pending items!')
        retry
      ensure
        win.keypad(false) if win
        win.close if win
      end

      class << self
        def draw_menu(win, menu_options, main, active_index = nil)
          win.clear
          win.attrset(Curses::A_NORMAL)
          win.box
          menu_options.each_with_index do |label, i|
            win.attrset(i == active_index ? Curses::A_STANDOUT : Curses::A_NORMAL)
            count_available = case label
                              when 'Review'
                                main.engine.common_query.count_available_reviews
                              when 'Lesson'
                                main.engine.common_query.count_available_lessons
                              when 'Report'
                                main.engine.common_query.count_pending_review_reports +
                                main.engine.common_query.count_pending_lesson_reports
                              else
                                ''
                              end
            win.setpos((1 + i) * 2, 1)
            win.addstr("#{count_available} ".rjust(6, ' '))
            win.addstr(label.ljust(12, ' '))
          end
          win.refresh
        end
      end
    end
  end
end

# rubocop: enable all
