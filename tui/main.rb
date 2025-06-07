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

        @main = Curses.init_screen
        Curses.noecho
        Curses.curs_set(0)
        @status_line = StatusLine.new(@main, @preferences, @cjk_renderer)
        @layout = []
        @layout << TitleScreen.new(@main, @preferences, @cjk_renderer)

        @engine = init_engine
        sleep(2)
      end

      private

      def init_engine(force_db_regen: false, api_key: nil)
        @status_line.status('Initializing the engine...')
        sleep(2)
        Engine.new(force_db_regen: force_db_regen, api_key: api_key)
        @status_line.clear
      rescue SchemaCorruptedError
        count_down('Corrupted schema detected. Regenerating', 5)
        init_engine(force_db_regen: true)
      rescue MissingApiKeyError
        @status_line.state('API key not set!')
        api_key = @status_line.win.getch
        @status_line.state("Captured #{api_key}!")
        sleep(2)
        init_engine(api_key: api_key, force_db_regen: force_db_regen)
      end

      def count_down(message, time, counted: 0)
        return if counted >= time

        @status_line.status("#{message} in #{time - counted} seconds...")
        sleep(1)
        count_down(message, time, counted: counted + 1)
      end
    end
  end
end
