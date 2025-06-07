require 'curses'

module WaniKaniTUI
  module TUI
    # Renders main menu dialog
    class MainMenu
      MENU_OPTIONS = %w[Review Lesson Exit].freeze

      attr_accessor :win

      def initialize(window, engine)
        @window = window
        @engine = engine
        win = Curses::Window.new((MENU_OPTIONS.length * 2) + 3, 20, (Curses.lines / 5) * 3, (Curses.cols - 20) / 2)
        win.keypad(true)
        position = 0

        draw_menu(win, position)
        while (ch = win.getch)
          case ch
          when 'w', 'k', Curses::Key::UP
            position -= 1
          when 's', 'j', Curses::Key::DOWN
            position += 1
          when Curses::Key::ENTER, 10, 13, 'l', Curses::Key::RIGHT
            return change_window(MENU_OPTIONS[position])
          when 27 # The escape key
            return nil
          end

          # Clamp position within valid range
          position = MENU_OPTIONS.length - 1 if position < 0
          position = 0 if position >= MENU_OPTIONS.length

          draw_menu(win, position)
        end
      end

      private

      def draw_menu(menu, active_index = nil)
        menu.clear
        menu.attrset(Curses::A_NORMAL)
        menu.box
        MENU_OPTIONS.each_with_index do |label, i|
          menu.attrset(i == active_index ? Curses::A_STANDOUT : Curses::A_NORMAL)
          count_available = case label
                            when 'Review'
                              @engine.common_query.count_available_reviews
                            when 'Lesson'
                              # TODO
                              ''
                            else
                              ''
                            end
          menu.setpos((1 + i) * 2, 1)
          menu.addstr("#{count_available} ".rjust(6, ' '))
          menu.addstr(label.ljust(12, ' '))
        end
        menu.refresh
      end

      def change_window(option)
        case option
        when 'Exit', nil
          nil
        when 'Review'
          # TODO
          nil
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
