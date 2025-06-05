# frozen_string_literal: true

require 'time'

require_relative 'db/database'
require_relative 'wanikani_api'
require_relative 'util/data_normalizer'
require_relative 'db/persister'
require_relative 'review'
require_relative 'util/data_dir'
require_relative 'cjk_renderer/cjk_renderer_bridge'
require_relative 'error/missing_api_key_error'

module WaniKaniTUI
  # Manages the core functionality of the application.
  class Engine
    # !!! Temp prototyping accessors, PURGE THESE BEFORE PRODUCTION YA DINGUS
    attr_accessor :db, :api, :preferences, :review, :cjk_renderer

    # rubocop: disable Metrics/MethodLength
    def initialize(force_db_regen: false, api_key: nil)
      if force_db_regen && api_key.nil?
        api_key = fetch_api_key # Attempts to carry over the previous API key to the new DB
        raise MissingApiKeyError, 'Could not fetch existing API key, new one is required' if api_key.nil?
      end

      @db = Database.new(force_db_regen: force_db_regen)
      @api = WaniKaniAPI.new(@db, api_key: api_key)
      fetch!

      @preferences = DataDir.preferences
      custom_buffer_size = @preferences['buffer_size']
      @review = custom_buffer_size ? Review.new(@db, buffer_size: custom_buffer_size) : Review.new(@db)
      custom_cjk_font = @preferences['cjk_font_path']
      @cjk_renderer = custom_cjk_font ? CJKRendererBridge.new(font_path: custom_cjk_font) : CJKRendererBridge.new
    end
    # rubocop: enable Metrics/MethodLength

    def fetch!
      updated_after = @db.get_first_row("SELECT value FROM meta WHERE key='updated_after'")

      subjects = DataNormalizer.subjects(@api.fetch_subjects(updated_after))
      assignments = DataNormalizer.assignments(@api.fetch_assignments(updated_after))
      Persister.persist(@db, DataNormalizer.unite!(subjects, assignments))

      @db.execute('INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)', ['updated_after', Time.now.utc.iso8601])
    end

    # ==============
    # Review section
    # ==============

    def get_review
      # Return structured hash with all the relevant data from the front of the buffer
      # e.g {review: {}, assignment: {}, subject: { ..., readings: {}, meaings: {}, components: {}, amalgamations: {}}}
    end

    def answer_review!(answer) # Expect a string (bang since this is will modify the db)
      # Return bool, whether the asnwer was correct
    end

    def last_review
      # Return structured has with all the relevant data from the end of the buffer
      # e.g {review: {}, assignment: {}, subject: { ..., readings: {}, meaings: {}, components: {}, amalgamations: {}}}
    end

    def progress_statuss_reviews
      # Return float, 0.0 - 1.0 representing % of all available reviews completed and unreported
    end

    def report_reviews!
      # Return bool whether report completed successfuly (beware of wanikaniAPI overloading)
    end

    private

    def fetch_api_key
      Database.new.get_first_row('SELECT value FROM meta WHERE key = ?', ['api_key'])&.first
    end
  end
end
