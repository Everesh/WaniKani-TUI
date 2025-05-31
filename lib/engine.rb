# frozen_string_literal: true

require_relative 'db/database'

module WaniKaniTUI
  # Manages the core functionality of the application.
  class Engine
    def initialize(force_db_regen: false)
      @db = WaniKaniTUI::Database.new(force_db_regen)
    end
  end
end
