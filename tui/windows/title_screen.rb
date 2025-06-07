require 'curses'

module WaniKaniTUI
  module TUI
    # Renders title screen
    class TitleScreen
      attr_accessor :win

      def initialize(preferences, cjk_renderer)
        @preferences = preferences
        @cjk_renderer = cjk_renderer
        @win = Curses::Window.new(Curses.lines - 3, Curses.cols, 0, 0)
        header
        @win.refresh
      end

      private

      def header
        text = '鰐蟹トゥイ'
        top_offset = Curses.lines / 4
        zero_gap = @preferences['no_line_spacing_correction']
        width = (Curses.cols * 2) / 3
        title = @cjk_renderer.get_braille(text, width, zero_gap: zero_gap, size_as_width: true)
        title.each_with_index do |row, i|
          @win.setpos(top_offset + i, ((Curses.cols - width) / 2) + 1)
          @win.addstr(row.join(''))
        end
      end
    end
  end
end
