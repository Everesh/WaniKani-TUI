# frozen_string_literal: true

require 'minitest/autorun'
require 'fileutils'
require_relative '../lib/db/database'

module WaniKaniTUI
  class TestDatabase < Minitest::Test
    TMP_DIR = File.expand_path('../tmp/test_data', __dir__)
    DB_PATH = File.join(TMP_DIR, 'db.sqlite3')

    def setup
      FileUtils.rm_f(DB_PATH)
      FileUtils.mkdir_p(TMP_DIR)
      ENV['XDG_DATA_HOME'] = TMP_DIR
    end

    def teardown
      FileUtils.rm_rf(TMP_DIR)
    end

    def test_initializes_and_creates_tables
      db = WaniKaniTUI::Database.new
      tables = db.instance_variable_get(:@db)
                 .execute("SELECT name FROM sqlite_master WHERE type='table'")
                 .map(&:values).flatten

      expected = File.read(WaniKaniTUI::Database::INIT_SQL).scan(/CREATE TABLE (\w+)/i).flatten
      assert_equal expected.sort, tables.sort
    end

    def test_raises_exception_if_schema_corrutped
      db = WaniKaniTUI::Database.new
      raw = db.instance_variable_get(:@db)

      raw.execute('DROP TABLE IF EXISTS subject')

      assert_raises(RuntimeError) do
        WaniKaniTUI::Database.new
      end
    end

    def test_regenerates_corrupted_schema_if_forced
      db = WaniKaniTUI::Database.new
      raw = db.instance_variable_get(:@db)

      raw.execute('DROP TABLE IF EXISTS subject')

      assert_silent do
        WaniKaniTUI::Database.new(force_regen: true)
      end
    end
  end
end
