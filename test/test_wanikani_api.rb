# frozen_string_literal: true
# rubocop: disable all

require 'minitest/autorun'
require 'fileutils'
require_relative '../lib/wanikani_api'
require_relative '../lib/db/database'
require_relative 'error/rate_limit_error'
require_relative 'error/invalid_api_key_error'
require_relative 'error/missing_api_key_error'

module WaniKaniTUI
  class TestWaniKaniAPI < Minitest::Test
    TMP_DIR = File.expand_path('../tmp/test_data', __dir__)
    DB_PATH = File.join(TMP_DIR, 'db.sqlite3')
    FAKE_KEY = 'abcdefgh-0000-ijkl-1111-mnopqrstuvwx'

    def setup
      FileUtils.rm_f(DB_PATH)
      FileUtils.mkdir_p(TMP_DIR)
      ENV['XDG_DATA_HOME'] = TMP_DIR
      @db = Database.new
    end

    def teardown
      FileUtils.rm_rf(TMP_DIR)
    end

    # Initialization tests
    def test_initialization_with_api_key
      api = WaniKaniAPI.new(@db, api_key: FAKE_KEY)
      stored_key = @db.get_first_row("SELECT value FROM meta WHERE key='api_key'").first
      assert_equal FAKE_KEY, stored_key
    end

    def test_initialization_with_cached_api_key
      @db.execute('INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)', ['api_key', FAKE_KEY])
      assert_silent { WaniKaniAPI.new(@db) }
    end

    def test_initialization_without_api_key
      assert_raises(MissingApiKeyError) { WaniKaniAPI.new(@db) }
    end

    # Successful API calls
    def test_fetch_subjects_success
      api = WaniKaniAPI.new(@db, api_key: FAKE_KEY)

      api.define_singleton_method(:request) do |uri, updated_after|
        mock_response = Object.new
        mock_response.define_singleton_method(:code) { '200' }
        mock_response.define_singleton_method(:body) do
          '{"data":[{"id":1,"object":"radical"},{"id":2,"object":"kanji"}],"pages":{"next_url":null}}'
        end
        mock_response
      end

      result = api.fetch_subjects(nil)
      assert_equal 2, result.length
      assert_equal 'radical', result[0]['object']
      assert_equal 'kanji', result[1]['object']
    end

    def test_fetch_assignments_success
      api = WaniKaniAPI.new(@db, api_key: FAKE_KEY)

      api.define_singleton_method(:request) do |uri, updated_after|
        mock_response = Object.new
        mock_response.define_singleton_method(:code) { '200' }
        mock_response.define_singleton_method(:body) do
          '{"data":[{"id":123,"object":"assignment"}],"pages":{"next_url":null}}'
        end
        mock_response
      end

      result = api.fetch_assignments(nil)
      assert_equal 1, result.length
      assert_equal 'assignment', result[0]['object']
    end

    def test_fetch_with_pagination
      api = WaniKaniAPI.new(@db, api_key: FAKE_KEY)

      call_count = 0
      api.define_singleton_method(:request) do |uri, updated_after|
        call_count += 1
        mock_response = Object.new
        mock_response.define_singleton_method(:code) { '200' }
        mock_response.define_singleton_method(:body) do
          if call_count == 1
            '{"data":[{"id":1,"object":"radical"}],"pages":{"next_url":"https://api.wanikani.com/v2/subjects?page=2"}}'
          else
            '{"data":[{"id":2,"object":"kanji"}],"pages":{"next_url":null}}'
          end
        end
        mock_response
      end

      result = api.fetch_subjects(nil)
      assert_equal 2, result.length
      assert_equal 1, result[0]['id']
      assert_equal 2, result[1]['id']
    end

    # Error handling tests
    def test_invalid_api_key_error
      api = WaniKaniAPI.new(@db, api_key: FAKE_KEY)

      api.define_singleton_method(:request) do |uri, updated_after|
        mock_response = Object.new
        mock_response.define_singleton_method(:code) { '401' }
        mock_response.define_singleton_method(:body) { '{"error":"Invalid API key"}' }
        mock_response
      end

      assert_raises(InvalidApiKeyError) do
        api.fetch_subjects(nil)
      end
    end

    def test_rate_limit_with_retry
      api = WaniKaniAPI.new(@db, api_key: FAKE_KEY)

      call_count = 0
      sleep_called = false
      sleep_duration = nil

      api.define_singleton_method(:request) do |uri, updated_after|
        call_count += 1
        mock_response = Object.new
        mock_response.define_singleton_method(:code) { call_count == 1 ? '429' : '200' }
        mock_response.define_singleton_method(:body) do
          if call_count == 1
            '{"error":"Rate limited"}'
          else
            '{"data":[{"id":1,"object":"radical"}],"pages":{"next_url":null}}'
          end
        end
        mock_response
      end

      api.define_singleton_method(:sleep) do |duration|
        sleep_called = true
        sleep_duration = duration
      end

      result = api.fetch_subjects(nil)
      assert sleep_called, 'Sleep should have been called for rate limiting'
      assert_equal 60, sleep_duration
      assert_equal 1, result.length
    end

    def test_client_error_raises_standard_error
      api = WaniKaniAPI.new(@db, api_key: FAKE_KEY)

      api.define_singleton_method(:request) do |uri, updated_after|
        mock_response = Object.new
        mock_response.define_singleton_method(:code) { '400' }
        mock_response.define_singleton_method(:body) { '{"error":"Bad request"}' }
        mock_response
      end

      assert_raises(StandardError) do
        api.fetch_subjects(nil)
      end
    end

    def test_empty_response
      api = WaniKaniAPI.new(@db, api_key: FAKE_KEY)

      api.define_singleton_method(:request) do |uri, updated_after|
        mock_response = Object.new
        mock_response.define_singleton_method(:code) { '200' }
        mock_response.define_singleton_method(:body) { '{"data":[],"pages":{"next_url":null}}' }
        mock_response
      end

      result = api.fetch_subjects(nil)
      assert_equal [], result
    end

    # Test parse_response method
    def test_parse_response_success
      api = WaniKaniAPI.new(@db, api_key: FAKE_KEY)

      mock_response = Object.new
      mock_response.define_singleton_method(:code) { '200' }
      mock_response.define_singleton_method(:body) { '{"data": [], "pages": {}}' }

      result = api.send(:parse_response, mock_response)
      assert_equal({}, result['pages'])
      assert_equal([], result['data'])
    end

    def test_parse_response_401_error
      api = WaniKaniAPI.new(@db, api_key: FAKE_KEY)

      mock_response = Object.new
      mock_response.define_singleton_method(:code) { '401' }
      mock_response.define_singleton_method(:body) { '{"error": "Unauthorized"}' }

      assert_raises(InvalidApiKeyError) do
        api.send(:parse_response, mock_response)
      end
    end

    def test_parse_response_429_error
      api = WaniKaniAPI.new(@db, api_key: FAKE_KEY)

      mock_response = Object.new
      mock_response.define_singleton_method(:code) { '429' }
      mock_response.define_singleton_method(:body) { '{"error": "Rate limited"}' }

      assert_raises(RateLimitError) do
        api.send(:parse_response, mock_response)
      end
    end

    def test_parse_response_other_4xx_error
      api = WaniKaniAPI.new(@db, api_key: FAKE_KEY)

      mock_response = Object.new
      mock_response.define_singleton_method(:code) { '400' }
      mock_response.define_singleton_method(:body) { '{"error": "Bad request"}' }

      assert_raises(StandardError) do
        api.send(:parse_response, mock_response)
      end
    end

    # Meta test, the original test suit binded to :parse_response
    # which let :request send unintentional http requests to the API
    def test_no_network_calls_made
      api = WaniKaniAPI.new(@db, api_key: FAKE_KEY)

      http_called = false
      Net::HTTP.define_singleton_method(:start) do |*args|
        http_called = true
        super(*args)
      end

      api.define_singleton_method(:request) do |uri, updated_after|
        mock_response = Object.new
        mock_response.define_singleton_method(:code) { '200' }
        mock_response.define_singleton_method(:body) { '{"data":[],"pages":{"next_url":null}}' }
        mock_response
      end

      api.fetch_subjects(nil)

      refute http_called, 'No network calls should be made when request method is mocked'
    end
  end
end
