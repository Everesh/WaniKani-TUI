require 'curses'

require_relative '../lib/engine'
require_relative '../lib/error/missing_api_key_error'
require_relative '../lib/cjk_renderer/cjk_renderer_bridge'
require_relative 'components/spinner'

module WaniKaniTUI
  module TUI
    # The main Curses TUI application class.
    class Main
      def initialize
        @master = Curses.init_screen
        Curses.noecho
        Curses.curs_set(0)

        text = '鰐蟹トゥイ'
        width = ((Curses.cols * 2) / 3)
        height = width / (text.length * 2)
        top_offset = Curses.lines / 4
        title = CJKRendererBridge.new.get_braille(text, height)
        title.each_with_index do |row, i|
          Curses.setpos(top_offset + i, ((Curses.cols - width) / 2) + 1)
          Curses.addstr(row.join(''))
        end

        spinner = Spinner.new(@master, Curses.lines - 2, 2)
        Curses.setpos(Curses.lines - 2, 5)
        Curses.addstr('loading...')
        sleep(15)
        spinner.stop
        Curses.setpos(Curses.lines - 2, 5)
        Curses.addstr('           ')
        Curses.setpos(top_offset + height + top_offset, ((Curses.cols - 'loaded!'.length) / 2) + 1)
        Curses.addstr('Loaded!')
        Curses.setpos(top_offset + height + top_offset + 2, ((Curses.cols - 'Press ANY button to exit'.length) / 2) + 1)
        Curses.addstr('Press ANY button to exit')
        Curses.getch
      end
    end
  end
end

WaniKaniTUI::TUI::Main.new
