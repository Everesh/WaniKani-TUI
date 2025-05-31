# frozen_string_literal: true

require 'sqlite3'
require 'fileutils'

module WaniKaniTUI
  class Database
    def initialize
      data_home = ENV['XDG_DATA_HOME'] || File.join(ENV['HOME'], '.local', 'share')
      app_data_dir = File.join(data_home, 'WaniKaniTUI')
      FileUtils.mkdir_p(app_data_dir)

      db_file = File.join(app_data_dir, 'db.sqlite3')
      @db = SQLite3::Database.open(db_file)
      @db.results_as_hash = true
      @db.execute('PRAGMA foreign_key = ON;')
    end
  end
end
