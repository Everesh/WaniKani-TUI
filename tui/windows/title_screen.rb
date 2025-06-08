# frozen_string_literal: true

require 'curses'

module WaniKaniTUI
  module TUI
    # Renders title screen
    class TitleScreen
      APP_TITLE = '鰐蟹トゥイ'

      attr_accessor :win

      def initialize(preferences, cjk_renderer)
        @preferences = preferences
        @cjk_renderer = cjk_renderer
        @win = Curses::Window.new(Curses.lines - 3, Curses.cols, 0, 0)
        draw
        @win.refresh
      end

      def draw
        header
      end

      private

      # rubocop: disable Metrics/AbcSize
      def header
        top_offset = Curses.lines / 5
        zero_gap = @preferences['no_line_spacing_correction']
        width = (Curses.cols * 2) / 3
        title = @cjk_renderer.get_braille(APP_TITLE, width, zero_gap: zero_gap, size_as_width: true)
        title.each_with_index do |row, i|
          @win.setpos(top_offset + i, ((Curses.cols - row.length) / 2) + 1)
          @win.addstr(row.join(''))
        end
      end
      # rubocop: enable Metrics/AbcSize
    end
  end
end
