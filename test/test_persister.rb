# frozen_string_literal: true
# rubocop: disable all

require 'minitest/autorun'
require 'fileutils'
require_relative '../lib/db/persister'
require_relative '../lib/db/database'

module WaniKaniTUI
  class TestPersister < Minitest::Test
    TMP_DIR = File.expand_path('../tmp/test_data', __dir__)
    DB_PATH = File.join(TMP_DIR, 'db.sqlite3')

    def setup
      FileUtils.rm_f(DB_PATH)
      FileUtils.mkdir_p(TMP_DIR)
      ENV['XDG_DATA_HOME'] = TMP_DIR
      @db = Database.new
    end

    def teardown
      FileUtils.rm_rf(TMP_DIR)
    end

    def test_persist_raises_error_for_invalid_db
      invalid_db = Object.new
      test_data = self.create_test_data

      assert_raises(ArgumentError, 'Expected a WaniKaniTUI::Database instance') do
        Persister.persist(invalid_db, test_data)
      end
    end

    def test_persist_complete_dataset
      test_data = self.create_test_data

      assert_silent do
        Persister.persist(@db, test_data)
      end

      # Verify subjects were inserted
      subjects = @db.execute('SELECT * FROM subject ORDER BY id')
      assert_equal 2, subjects.length
      assert_equal [1, '一', 1, 'radical', 'ground', 'https://example.com/radical', 'Ground mnemonic', nil], subjects[0]
      assert_equal [440, '人', 1, 'kanji', 'person', 'https://example.com/kanji', 'Person mnemonic', 'Reading mnemonic'], subjects[1]

      # Verify meanings were inserted
      meanings_lookup = @db.execute('SELECT * FROM meaning ORDER BY meaning')
      assert_equal 2, meanings_lookup.length
      assert_equal ['Ground'], meanings_lookup[0]
      assert_equal ['Person'], meanings_lookup[1]

      subject_meanings = @db.execute('SELECT * FROM subject_meaning ORDER BY id, meaning')
      assert_equal 2, subject_meanings.length
      assert_equal [1, 'Ground', 1, 1], subject_meanings[0]
      assert_equal [440, 'Person', 1, 1], subject_meanings[1]

      # Verify readings were inserted
      readings_lookup = @db.execute('SELECT * FROM reading ORDER BY reading')
      assert_equal 1, readings_lookup.length
      assert_equal ['じん'], readings_lookup[0]

      subject_readings = @db.execute('SELECT * FROM subject_reading ORDER BY id, reading')
      assert_equal 1, subject_readings.length
      assert_equal [440, 'じん', 1, 1, 'onyomi'], subject_readings[0]

      # Verify components were inserted
      components = @db.execute('SELECT * FROM components ORDER BY id_component, id_product')
      assert_equal 1, components.length
      assert_equal [1, 440], components[0]

      # Verify assignments were inserted
      assignments = @db.execute('SELECT * FROM assignment ORDER BY assignment_id')
      assert_equal 1, assignments.length
      assert_equal [123, 440, 5, 0, '2023-01-01T00:00:00Z', '2023-01-01T00:00:00Z'], assignments[0]
    end

    def test_persist_empty_data
      empty_data = {
        subjects: [],
        meanings: [],
        readings: [],
        components: [],
        assignments: []
      }

      assert_silent do
        Persister.persist(@db, empty_data)
      end

      # Verify no data was inserted
      assert_equal [], @db.execute('SELECT * FROM subject')
      assert_equal [], @db.execute('SELECT * FROM meaning')
      assert_equal [], @db.execute('SELECT * FROM reading')
      assert_equal [], @db.execute('SELECT * FROM components')
      assert_equal [], @db.execute('SELECT * FROM assignment')
    end

    def test_persist_subjects_with_null_characters
      test_data = {
        subjects: [
          [1, nil, 1, 'radical', 'test', 'https://example.com', nil, 'Test mnemonic']
        ],
        meanings: [],
        readings: [],
        components: [],
        assignments: []
      }

      assert_silent do
        Persister.persist(@db, test_data)
      end

      subject = @db.execute('SELECT * FROM subject WHERE id = 1')[0]
      assert_equal [1, nil, 1, 'radical', 'test', 'https://example.com', 'Test mnemonic', nil], subject
    end

    def test_persist_meanings_with_duplicate_text
      test_data = {
        subjects: [
          [1, '一', 1, 'radical', 'ground', 'https://example.com', nil, 'Mnemonic'],
          [2, '二', 1, 'radical', 'two', 'https://example.com', nil, 'Mnemonic']
        ],
        meanings: [
          [1, 'Ground', 1, 1],
          [2, 'Ground', 1, 1]  # Same meaning text for different subjects
        ],
        readings: [],
        components: [],
        assignments: []
      }

      assert_silent do
        Persister.persist(@db, test_data)
      end

      # Should only have one meaning entry in lookup table
      meanings = @db.execute('SELECT * FROM meaning')
      assert_equal 1, meanings.length
      assert_equal ['Ground'], meanings[0]

      # But two subject_meaning entries
      subject_meanings = @db.execute('SELECT * FROM subject_meaning ORDER BY id')
      assert_equal 2, subject_meanings.length
      assert_equal [1, 'Ground', 1, 1], subject_meanings[0]
      assert_equal [2, 'Ground', 1, 1], subject_meanings[1]
    end

    def test_persist_readings_with_duplicate_text
      test_data = {
        subjects: [
          [440, '人', 1, 'kanji', 'person', 'https://example.com', 'Reading mnemonic', 'Person mnemonic'],
          [441, '入', 1, 'kanji', 'enter', 'https://example.com', 'Reading mnemonic', 'Enter mnemonic']
        ],
        meanings: [],
        readings: [
          [440, 'にん', 1, 1, 'onyomi'],
          [441, 'にん', 1, 1, 'onyomi']  # Same reading for different kanji
        ],
        components: [],
        assignments: []
      }

      assert_silent do
        Persister.persist(@db, test_data)
      end

      # Should only have one reading entry in lookup table
      readings = @db.execute('SELECT * FROM reading')
      assert_equal 1, readings.length
      assert_equal ['にん'], readings[0]

      # But two subject_reading entries
      subject_readings = @db.execute('SELECT * FROM subject_reading ORDER BY id')
      assert_equal 2, subject_readings.length
      assert_equal [440, 'にん', 1, 1, 'onyomi'], subject_readings[0]
      assert_equal [441, 'にん', 1, 1, 'onyomi'], subject_readings[1]
    end

    def test_persist_with_replace_behavior
      # Insert initial data
      initial_data = {
        subjects: [
          [1, '一', 1, 'radical', 'ground', 'https://example.com', nil, 'Old mnemonic']
        ],
        meanings: [
          [1, 'Ground', 1, 1]
        ],
        readings: [],
        components: [],
        assignments: []
      }

      Persister.persist(@db, initial_data)

      # Update with new data (same IDs)
      updated_data = {
        subjects: [
          [1, '一', 1, 'radical', 'ground', 'https://example.com', nil, 'New mnemonic']
        ],
        meanings: [
          [1, 'Ground', 0, 1]  # Changed primary flag
        ],
        readings: [],
        components: [],
        assignments: []
      }

      assert_silent do
        Persister.persist(@db, updated_data)
      end

      # Verify data was replaced, not duplicated
      subjects = @db.execute('SELECT * FROM subject')
      assert_equal 1, subjects.length
      assert_equal 'New mnemonic', subjects[0][6]  # mnemonic_meaning is column 6

      subject_meanings = @db.execute('SELECT * FROM subject_meaning')
      assert_equal 1, subject_meanings.length
      assert_equal [1, 'Ground', 0, 1], subject_meanings[0]
    end

    def test_persist_large_dataset
      # Test with larger dataset to ensure performance
      subjects = []
      meanings = []

      (1..100).each do |i|
        subjects << [i, "字#{i}", 1, 'kanji', "test#{i}", "https://example.com/#{i}", nil, "Mnemonic #{i}"]
        meanings << [i, "Meaning #{i}", 1, 1]
      end

      large_data = {
        subjects: subjects,
        meanings: meanings,
        readings: [],
        components: [],
        assignments: []
      }

      assert_silent do
        Persister.persist(@db, large_data)
      end

      # Verify all data was inserted
      assert_equal 100, @db.execute('SELECT COUNT(*) FROM subject')[0][0]
      assert_equal 100, @db.execute('SELECT COUNT(*) FROM meaning')[0][0]
      assert_equal 100, @db.execute('SELECT COUNT(*) FROM subject_meaning')[0][0]
    end

    def test_transaction_rollback_on_error
      # Create mock database that will fail on second operation
      mock_db = Minitest::Mock.new
      mock_db.expect :is_a?, true, [WaniKaniTUI::Database]

      # Expect transaction to be called
      mock_db.expect :transaction, nil do |&block|
        # This will raise an error during execution
        raise StandardError, 'Database error'
      end

      test_data = self.create_test_data

      assert_raises(StandardError) do
        Persister.persist(mock_db, test_data)
      end

      mock_db.verify
    end

    def test_persist_components_relationships
      test_data = {
        subjects: [
          [1, '一', 1, 'radical', 'ground', 'https://example.com', nil, 'Radical'],
          [440, '人', 1, 'kanji', 'person', 'https://example.com', 'Reading', 'Kanji'],
          [2467, '人', 1, 'vocabulary', 'person', 'https://example.com', 'Reading', 'Vocab']
        ],
        meanings: [],
        readings: [],
        components: [
          [1, 440],    # radical -> kanji
          [440, 2467]  # kanji -> vocabulary
        ],
        assignments: []
      }

      assert_silent do
        Persister.persist(@db, test_data)
      end

      components = @db.execute('SELECT * FROM components ORDER BY id_component, id_product')
      assert_equal 2, components.length
      assert_equal [1, 440], components[0]
      assert_equal [440, 2467], components[1]
    end

    def test_persist_assignments_with_null_timestamps
      test_data = {
        subjects: [
          [440, '人', 1, 'kanji', 'person', 'https://example.com', 'Reading mnemonic', 'Person mnemonic']
        ],
        meanings: [],
        readings: [],
        components: [],
        assignments: [
          [123, 440, 0, 0, nil, nil]  # Assignment with null timestamps
        ]
      }

      assert_silent do
        Persister.persist(@db, test_data)
      end

      assignment = @db.execute('SELECT * FROM assignment WHERE assignment_id = 123')[0]
      assert_equal [123, 440, 0, 0, nil, nil], assignment
    end

    private

    def create_test_data
      {
        subjects: [
          [1, '一', 1, 'radical', 'ground', 'https://example.com/radical', nil, 'Ground mnemonic'],
          [440, '人', 1, 'kanji', 'person', 'https://example.com/kanji', 'Reading mnemonic', 'Person mnemonic']
        ],
        meanings: [
          [1, 'Ground', 1, 1],
          [440, 'Person', 1, 1]
        ],
        readings: [
          [440, 'じん', 1, 1, 'onyomi']
        ],
        components: [
          [1, 440]  # radical -> kanji relationship
        ],
        assignments: [
          [123, 440, 5, 0, '2023-01-01T00:00:00Z', '2023-01-01T00:00:00Z']
        ]
      }
    end
  end
end
