require 'curses'

module WaniKaniTUI
  module TUI
    # Renders title screen
    class TitleScreen
      APP_TITLE = '鰐蟹トゥイ'
      MENU_OPTIONS = %w[Review Lesson Exit].freeze

      attr_accessor :win

      def initialize(preferences, cjk_renderer)
        @preferences = preferences
        @cjk_renderer = cjk_renderer
        @win = Curses::Window.new(Curses.lines - 3, Curses.cols, 0, 0)
        header

        @position = 0
        @menu = Curses::Window.new(5, 20, (Curses.lines / 5) * 3, (Curses.cols - 20) / 2)
        @menu.keypad(true)

        @win.refresh
        @menu.refresh
      end

      def main_menu
        draw_menu(@menu, @position)
        while (ch = @menu.getch)
          case ch
          when 'w', 'k', Curses::Key::UP
            @position -= 1
          when 's', 'j', Curses::Key::DOWN
            @position += 1
          when Curses::Key::ENTER, 10, 13, 'l', Curses::Key::RIGHT
            return MENU_OPTIONS[@position]
          end

          # Clamp position within valid range
          @position = MENU_OPTIONS.length - 1 if @position < 0
          @position = 0 if @position >= MENU_OPTIONS.length

          draw_menu(@menu, @position)
        end
      end

      private

      def header
        top_offset = Curses.lines / 4
        zero_gap = @preferences['no_line_spacing_correction']
        width = (Curses.cols * 2) / 3
        title = @cjk_renderer.get_braille(APP_TITLE, width, zero_gap: zero_gap, size_as_width: true)
        title.each_with_index do |row, i|
          @win.setpos(top_offset + i, ((Curses.cols - width) / 2) + 1)
          @win.addstr(row.join(''))
        end
      end

      def draw_menu(menu, active_index = nil)
        menu.clear
        MENU_OPTIONS.each_with_index do |label, i|
          menu.setpos(i * 2, 2)
          menu.attrset(i == active_index ? Curses::A_STANDOUT : Curses::A_NORMAL)
          menu.addstr(label)
        end
        menu.refresh
      end
    end
  end
end
