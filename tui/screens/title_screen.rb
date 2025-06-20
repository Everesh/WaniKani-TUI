# frozen_string_literal: true

require 'curses'

module WaniKaniTUI
  module TUI
    # Renders title screen
    class TitleScreen
      APP_TITLE = '鰐蟹トゥイ'

      attr_accessor :win

      def initialize(main)
        @main = main
      end

      def show
        @win = Curses::Window.new(Curses.lines - 1, Curses.cols, 0, 0)
        @win.bkgd(Curses.color_pair(1))
        @win.clear
        draw_title
        @win.refresh
      end

      private

      # rubocop: disable Metrics/AbcSize
      def draw_title
        zero_gap = @main.preferences['no_line_spacing_correction']
        width = (Curses.cols * 2) / 3
        title = @main.cjk_renderer.get_braille(APP_TITLE, width, zero_gap: zero_gap, size_as_width: true)
        top_offset = [[Curses.lines / 5, Curses.lines - 17 - title.length].min, 2].max
        @win.attron(Curses::A_BOLD)
        title.each_with_index do |row, i|
          @win.setpos(top_offset + i, ((Curses.cols - row.length) / 2) + 1)
          @win.addstr(row.join(''))
        end
        @win.attroff(Curses::A_BOLD)
      end
      # rubocop: enable Metrics/AbcSize
    end
  end
end
