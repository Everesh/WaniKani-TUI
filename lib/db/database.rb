# frozen_string_literal: true

require 'sqlite3'
require 'fileutils'

require_relative '../util/data_dir'
require_relative '../error/schema_corrupted_error'

module WaniKaniTUI
  # Handles SQLite3 database connection and schema initialization
  class Database
    INIT_SQL = File.expand_path('init.sql', __dir__)
    DROP_SQL = File.expand_path('drop.sql', __dir__)
    DB_FILE_NAME = 'db.sqlite3'

    def initialize(force_db_regen: false, check_bypass: false)
      DataDir.ensure!

      db_file = File.join(DataDir.path, DB_FILE_NAME)
      @db = SQLite3::Database.open(db_file)

      @db.execute('PRAGMA foreign_keys = ON;')

      force_db_regen ? db_init : (check_schema! unless check_bypass)
    end

    def execute(sql, params = [])
      @db.execute(sql, params)
    end

    def execute_batch(sql)
      @db.execute_batch(sql)
    end

    def get_first_row(sql, params = [])
      @db.get_first_row(sql, params)
    end

    def transaction(&block)
      @db.transaction(&block)
    end

    def results_as_hash=(bool)
      @db.results_as_hash = bool
    end

    private

    def check_schema!
      tables = @db.execute("SELECT name FROM sqlite_master WHERE type='table'").flatten
      expected_tables = File.read(INIT_SQL).scan(/CREATE TABLE (\w+)/i).flatten

      missing = expected_tables - tables
      return if missing.empty?

      raise SchemaCorruptedError, 'Database schema is corrupted!' if missing.length != expected_tables.length

      db_init
    end

    def db_init
      @db.execute_batch(File.read(DROP_SQL))
      @db.execute_batch(File.read(INIT_SQL))
    end
  end
end
