# frozen_string_literal: true

require 'minitest/autorun'
require 'fileutils'
require_relative '../lib/wanikani_api'
require_relative '../lib/db/database'

module WaniKaniTUI
  class TestWaniKaniAPI < Minitest::Test
    TMP_DIR = File.expand_path('../tmp/test_data', __dir__)
    DB_PATH = File.join(TMP_DIR, 'db.sqlite3')
    FAKE_KEY = 'abcdefgh-0000-ijkl-1111-mnopqrstuvwx'

    def setup
      FileUtils.rm_f(DB_PATH)
      FileUtils.mkdir_p(TMP_DIR)
      ENV['XDG_DATA_HOME'] = TMP_DIR
    end

    def teardown
      FileUtils.rm_rf(TMP_DIR)
    end

    def test_no_api_key_cached
      db = Database.new
      assert_raises(RuntimeError) do
        WaniKaniAPI.new(db)
      end
    end

    def test_api_key_cached
      db = Database.new
      db.execute('INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)', ['api_key', FAKE_KEY])
      assert_silent do
        WaniKaniAPI.new(db)
      end
    end

    def test_introducing_api_key
      db = Database.new
      assert_silent do
        WaniKaniAPI.new(db, api_key: FAKE_KEY)
      end
      assert_equal(FAKE_KEY, db.get_first_row("SELECT value FROM meta WHERE key='api_key'").first)
    end
  end
end
