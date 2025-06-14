# frozen_string_literal: true

require 'curses'
require 'yaml'
require 'fileutils'

require_relative '../lib/engine'
require_relative '../lib/error/missing_api_key_error'
require_relative 'cjk_renderer/cjk_renderer_bridge'
require_relative '../lib/util/data_dir'
require_relative 'components/status_line'
require_relative 'components/main_menu'
require_relative 'screens/title_screen'
require_relative 'screens/review_screen'

module WaniKaniTUI
  module TUI
    # The main Curses TUI application class.
    class Main
      attr_reader :preferences, :cjk_renderer, :status_line, :engine
      attr_accessor :screens, :overlays

      # rubocop: disable Metrics/MethodLength
      def initialize
        Curses.init_screen
        Curses.noecho
        Curses.curs_set(0)
        @preferences = DataDir.preferences
        Curses.start_color
        init_colors
        init_pairs
        @cjk_renderer = CJKRendererBridge.new(font_path: @preferences['cjk_font_path'])
        @screens = {}
        init_screens
        @screens['title'].open
        @status_line = StatusLine.new(self)
        @engine = init_engine
        @status_line.update_last_sync
        @overlays = {}
        init_overlays
        @overlays['main_menu'].open
      rescue Interrupt
        @status_line.state('Exiting...')
        # Could bind reporting on exit here :shrug:
      ensure
        Curses.close_screen
      end
      # rubocop: enable Metrics/MethodLength

      private

      # rubocop: disable Metrics/AbcSize, Metrics/MethodLength
      def init_engine(force_db_regen: false, api_key: nil)
        @status_line.status('Initializing the engine...')
        Engine.new(force_db_regen: force_db_regen, api_key: api_key)
      rescue SchemaCorruptedError
        @status_line.state('Corrupted schema detected. Do you want to regenereate it?: [y/N]')
        raise SchemaCorruptedError, 'Did not attemp to regenerate it.' unless @status_line.win.getch.downcase == 'y'

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
      ensure
        @status_line.clear
      end
      # rubocop: enable Metrics/AbcSize, Metrics/MethodLength

      def init_screens
        @screens['title'] = TitleScreen.new(self)
        @screens['review'] = ReviewScreen.new(self)
      end

      def init_overlays
        @overlays['main_menu'] = MainMenu.new(self)
      end

      def count_down(message, time, counted: 0)
        return if counted >= time

        @status_line.status("#{message} in #{time - counted} seconds...")
        sleep(1)
        count_down(message, time, counted: counted + 1)
      end

      def init_colors
        return unless Curses.can_change_color?

        base = YAML.load_file(File.join(__dir__, 'colors', "#{@preferences['theme'] || 'default'}.yml"))
        custom_colors = @preferences['colors'] || {}
        merged = {
          background: custom_colors['background'] || base['background'],
          foreground: custom_colors['foreground'] || base['foreground'],
          radical: custom_colors['radical'] || base['radical'],
          kanji: custom_colors['kanji'] || base['kanji'],
          vocab: custom_colors['vocab'] || base['vocab'],
          progress: custom_colors['progress'] || base['progress']
        }

        Curses.init_color(1, *hex_to_curses_rgb(merged[:background]))
        Curses.init_color(2, *hex_to_curses_rgb(merged[:foreground]))
        Curses.init_color(3, *hex_to_curses_rgb(merged[:radical]))
        Curses.init_color(4, *hex_to_curses_rgb(merged[:kanji]))
        Curses.init_color(5, *hex_to_curses_rgb(merged[:vocab]))
        Curses.init_color(6, *hex_to_curses_rgb(merged[:progress]))
      end

      def init_pairs
        if Curses.can_change_color?
          Curses.init_pair(1, 2, 1) # default fg bg
          Curses.init_pair(2, 1, 2) # inverted fg bg
          if @preferences['dark_cjk']
            Curses.init_pair(3, 1, 3) # radical
            Curses.init_pair(4, 1, 4) # kanji
            Curses.init_pair(5, 1, 5) # vocab
          else
            Curses.init_pair(3, 2, 3) # radical
            Curses.init_pair(4, 2, 4) # kanji
            Curses.init_pair(5, 2, 5) # vocab
          end
          if @preferences['theme'] && @preferences['theme'] == 'wanikani'
            Curses.init_pair(6, 6, 2) # progress - inverted bg
          else
            Curses.init_pair(6, 6, 1) # progress
          end
        else
          Curses.init_pair(1, Curses::COLOR_WHITE, Curses::COLOR_BLACK) # default fg bg
          Curses.init_pair(2, Curses::COLOR_BLACK, Curses::COLOR_WHILE) # inverted fg bg
          Curses.init_pair(3, Curses::COLOR_WHITE, Curses::COLOR_BLUE) # radical
          Curses.init_pair(4, Curses::COLOR_WHITE, Curses::COLOR_RED) # kanji
          Curses.init_pair(5, Curses::COLOR_WHITE, Curses::COLOR_GREEN) # vocab
          Curses.init_pair(6, Curses::COLOR_YELLOW, Curses::COLOR_BLACK) # progress
        end
      end

      def hex_to_curses_rgb(hex)
        hex = hex.delete('#')
        r, g, b = hex.scan(/../).map { |c| c.to_i(16) }
        [r, g, b].map { |val| (val / 255.0 * 1000).round }
      end
    end
  end
end
