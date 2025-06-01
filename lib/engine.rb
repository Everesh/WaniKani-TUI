# frozen_string_literal: true

require 'time'

require_relative 'db/database'
require_relative 'wanikani_api'
require_relative 'util/data_normalizer'
require_relative 'db/persister'

module WaniKaniTUI
  # Manages the core functionality of the application.
  class Engine
    def initialize(force_db_regen: false, api_key: nil)
      @db = Database.new(force_db_regen: force_db_regen)
      @api = WaniKaniAPI.new(@db, api_key: api_key)
      fetch!
    end

    def fetch!
      updated_after = @db.get_first_row("SELECT value FROM meta WHERE key='updated_after'")

      subjects = DataNormalizer.subjects(@api.fetch_subjects(updated_after))
      assignments = DataNormalizer.assignments(@api.fetch_assignments(updated_after))
      Persister.persist(DataNormalizer.unite!(subjects, assignments))

      @db.execute('INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)', ['updated_after', Time.now.utc.iso8601])
    end
  end
end
