require 'curses'

require_relative '../lib/engine'
require_relative '../lib/error/missing_api_key_error'
require_relative 'cjk_renderer/cjk_renderer_bridge'
require_relative '../lib/util/data_dir'
require_relative 'windows/title_screen'
require_relative 'windows/status_line'

module WaniKaniTUI
  module TUI
    # The main Curses TUI application class.
    class Main
      def initialize
        @preferences = DataDir.preferences
        custom_cjk_font = @preferences['cjk_font_path']
        @cjk_renderer = custom_cjk_font ? CJKRendererBridge.new(font_path: custom_cjk_font) : CJKRendererBridge.new

        Curses.init_screen
        Curses.noecho
        Curses.curs_set(0)

        @status_line = StatusLine.new(@preferences, @cjk_renderer)
        @window = TitleScreen.new(@preferences, @cjk_renderer)

        @engine = init_engine
        main_menu
      rescue Interrupt
        @status_line.state('Exiting...')
      ensure
        Curses.close_screen
      end

      private

      def init_engine(force_db_regen: false, api_key: nil)
        @status_line.status('Initializing the engine...')
        Engine.new(force_db_regen: force_db_regen, api_key: api_key)
        @status_line.clear
      rescue SchemaCorruptedError
        count_down('Corrupted schema detected. Regenerating', 5)
        init_engine(force_db_regen: true)
      rescue MissingApiKeyError, InvalidApiKeyError => e
        @status_line.state(e.message)
        sleep(1)
        @status_line.state('Enter an API key: ')
        Curses.echo
        @status_line.win.setpos(1, 24)
        api_key = @status_line.win.getstr.strip
        Curses.noecho
        @status_line.state("Captured '#{api_key}'!")
        sleep(1)
        init_engine(api_key: api_key, force_db_regen: force_db_regen)
      end

      def count_down(message, time, counted: 0)
        return if counted >= time

        @status_line.status("#{message} in #{time - counted} seconds...")
        sleep(1)
        count_down(message, time, counted: counted + 1)
      end

      def main_menu
        case @window.main_menu
        when 'Exit'
          nil
        when 'Review'
          @window = ReviewWindow.new # TODO
        when 'Lesson'
          @window = LessonWindow.new # TODO
        end
      end
    end
  end
end
