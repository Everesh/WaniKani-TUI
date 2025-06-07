# frozen_string_literal: true

require 'json'
require 'fileutils'

require_relative 'get_local_data'
require_relative '../lib/db/database'
require_relative '../lib/error/missing_api_key_error'

module WaniKaniTUI
  # Mocks interaction between the app and the WaniKani API
  class MockWaniKaniAPI
    def initialize(db, api_key: nil)
      @db = db
      @api_key = api_key || fetch_api_key
      raise MissingApiKeyError, 'API key not set!' unless @api_key

      GetLocalData.new(api_key: @api_key)
      store_api_key(@api_key) if api_key
    end

    def fetch_subjects(updated_after)
      JSON.load_file(File.join(__dir__, 'subjects.json'))
    end

    def fetch_assignments(updated_after)
      JSON.load_file(File.join(__dir__, 'assignments.json'))
    end

    private

    def fetch_api_key
      @db.get_first_row('SELECT value FROM meta WHERE key = ?', ['api_key'])&.first
    end

    def store_api_key(key)
      @db.execute('INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)', ['api_key', key])
    end
  end
end
