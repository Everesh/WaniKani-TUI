# frozen_string_literal: true

require 'sqlite3'
require 'fileutils'

module WaniKaniTUI
  # Handles SQLite3 database connection and schema initialization
  class Database
    INIT_SQL = File.expand_path('init.sql', __dir__)
    DROP_SQL = File.expand_path('drop.sql', __dir__)

    def initialize(force_regen: false)
      data_home = ENV['XDG_DATA_HOME'] || File.join(ENV['HOME'], '.local', 'share')
      app_data_dir = File.join(data_home, 'WaniKaniTUI')
      FileUtils.mkdir_p(app_data_dir)

      db_file = File.join(app_data_dir, 'db.sqlite3')
      @db = SQLite3::Database.open(db_file)
      @db.execute('PRAGMA foreign_keys = ON;')
      @db.results_as_hash = true
      force_regen ? db_init : check_schema!
    end

    private

    def check_schema!
      tables = @db.execute("SELECT name FROM sqlite_master WHERE type='table'").map(&:values).flatten
      expected_tables = File.read(INIT_SQL).scan(/CREATE TABLE (\w+)/i).flatten

      missing = expected_tables - tables
      return if missing.empty?

      missing.length == expected_tables.length ? db_init : raise('Database schema is corrupted')
    end

    def db_init
      @db.execute_batch(File.read(DROP_SQL))
      @db.execute_batch(File.read(INIT_SQL))
    end
  end
end
