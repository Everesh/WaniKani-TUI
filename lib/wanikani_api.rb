# frozen_string_literal: true

require_relative 'db/database'

module WaniKaniTUI
  # Handles the interaction between the app and the WaniKani API
  class WaniKaniAPI
    def initialize(db, api_key: nil)
      @db = db
      if api_key
        @api_key = api_key
        @db.execute('INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)', ['api_key', api_key])
      else
        @api_key = @db.get_first_row("SELECT value FROM meta WHERE key='api_key'")
        raise 'API key not set!' if @api_key.nil?
      end
    end

    def fetch_subjects(update_after)
      # TODO
    end

    def fetch_assignments(update_after)
      # TODO
    end
  end
end
