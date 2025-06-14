# frozen_string_literal: true
# rubocop: disable all

require 'minitest/autorun'
require_relative '../lib/util/data_normalizer'

module WaniKaniTUI
  class TestDataNormalizer < Minitest::Test
    def test_radical_subject_normalization
      radical_data = [{
        'id' => 1,
        'object' => 'radical',
        'data' => {
          'characters' => '一',
          'level' => 1,
          'slug' => 'ground',
          'document_url' => 'https://www.wanikani.com/radicals/ground',
          'meanings' => [
            { 'meaning' => 'Ground', 'primary' => true, 'accepted_answer' => true },
            { 'meaning' => 'Floor', 'primary' => false, 'accepted_answer' => true }
          ],
          'amalgamation_subject_ids' => [440, 449],
          'meaning_mnemonic' => 'This is the ground'
        }
      }]

      result = DataNormalizer.subjects(radical_data)

      # Test subject extraction
      assert_equal 1, result[:subjects].length
      subject = result[:subjects][0]
      assert_equal [1, '一', 1, 'radical', 'ground',
                   'https://www.wanikani.com/radicals/ground', nil, 'This is the ground', nil], subject

      # Test meanings extraction
      assert_equal 2, result[:meanings].length
      assert_equal [1, 'Ground', 1, 1], result[:meanings][0]
      assert_equal [1, 'Floor', 0, 1], result[:meanings][1]

      # Test readings (should be empty for radicals)
      assert_equal [], result[:readings]

      # Test components (should also be empty, only kanjis create components)
      assert_equal [], result[:components]
    end

    def test_kanji_subject_normalization
      kanji_data = [{
        'id' => 440,
        'object' => 'kanji',
        'data' => {
          'characters' => '人',
          'level' => 1,
          'slug' => 'person',
          'document_url' => 'https://www.wanikani.com/kanji/person',
          'meanings' => [
            { 'meaning' => 'Person', 'primary' => true, 'accepted_answer' => true }
          ],
          'readings' => [
            { 'reading' => 'じん', 'primary' => true, 'accepted_answer' => true, 'type' => 'onyomi' },
            { 'reading' => 'にん', 'primary' => false, 'accepted_answer' => true, 'type' => 'onyomi' }
          ],
          'component_subject_ids' => [1, 2],
          'amalgamation_subject_ids' => [500, 501],
          'meaning_mnemonic' => 'Person mnemonic',
          'reading_mnemonic' => 'Reading mnemonic',
          'hidden_at' => nil
        }
      }]

      result = DataNormalizer.subjects(kanji_data)

      # Test subject extraction
      assert_equal 1, result[:subjects].length
      subject = result[:subjects][0]
      assert_equal [440, '人', 1, 'kanji', 'person',
                   'https://www.wanikani.com/kanji/person', 'Reading mnemonic', 'Person mnemonic', nil], subject

      # Test meanings
      assert_equal 1, result[:meanings].length
      assert_equal [440, 'Person', 1, 1], result[:meanings][0]

      # Test readings
      assert_equal 2, result[:readings].length
      assert_equal [440, 'じん', 1, 1, 'onyomi'], result[:readings][0]
      assert_equal [440, 'にん', 0, 1, 'onyomi'], result[:readings][1]

      # Test components
      assert_equal 4, result[:components].length
      assert_equal [1, 440], result[:components][0]  # component relationship
      assert_equal [2, 440], result[:components][1]  # component relationship
      assert_equal [440, 500], result[:components][2] # amalgamation relationship
      assert_equal [440, 501], result[:components][3] # amalgamation relationship
    end

    def test_vocabulary_subject_normalization
      vocab_data = [{
        'id' => 2467,
        'object' => 'vocabulary',
        'data' => {
          'characters' => '人',
          'level' => 1,
          'slug' => 'person',
          'document_url' => 'https://www.wanikani.com/vocabulary/person',
          'meanings' => [
            { 'meaning' => 'Person', 'primary' => true, 'accepted_answer' => true }
          ],
          'readings' => [
            { 'reading' => 'ひと', 'primary' => true, 'accepted_answer' => true, 'type' => 'kunyomi' }
          ],
          'meaning_mnemonic' => 'Vocab meaning mnem',
          'reading_mnemonic' => 'Vocab reading mnem'
        }
      }]

      result = DataNormalizer.subjects(vocab_data)

      # Test subject extraction
      assert_equal 1, result[:subjects].length
      subject = result[:subjects][0]
      assert_equal [2467, '人', 1, 'vocabulary', 'person',
                   'https://www.wanikani.com/vocabulary/person', 'Vocab reading mnem', 'Vocab meaning mnem', nil], subject

      # Test meanings
      assert_equal 1, result[:meanings].length
      assert_equal [2467, 'Person', 1, 1], result[:meanings][0]

      # Test readings
      assert_equal 1, result[:readings].length
      assert_equal [2467, 'ひと', 1, 1, 'kunyomi'], result[:readings][0]

      # Test components (should be empty, only kanjis create components)
      assert_equal [], result[:components]
    end

    def test_kana_vocabulary_subject_normalization
      kana_vocab_data = [{
        'id' => 8770,
        'object' => 'kana_vocabulary',
        'data' => {
          'characters' => 'ひとつ',
          'level' => 2,
          'slug' => 'one-thing',
          'document_url' => 'https://www.wanikani.com/vocabulary/one-thing',
          'meanings' => [
            { 'meaning' => 'One Thing', 'primary' => true, 'accepted_answer' => true }
          ],

          'meaning_mnemonic' => 'Kana vocab meaning'
        }
      }]

      result = DataNormalizer.subjects(kana_vocab_data)

      # Test subject extraction
      assert_equal 1, result[:subjects].length
      subject = result[:subjects][0]
      assert_equal [8770, 'ひとつ', 2, 'kana_vocabulary', 'one-thing',
                   'https://www.wanikani.com/vocabulary/one-thing', nil, 'Kana vocab meaning', nil], subject

      # Test meanings
      assert_equal 1, result[:meanings].length
      assert_equal [8770, 'One Thing', 1, 1], result[:meanings][0]

      # Test readings (should be empty, only kanji and vocabulary have readings)
      assert_equal [], result[:readings]

      # Test components (should be empty, only kanjis create components)
      assert_equal [], result[:components]
    end

    def test_empty_data_handling
      empty_data = []
      result = DataNormalizer.subjects(empty_data)

      assert_equal [], result[:subjects]
      assert_equal [], result[:meanings]
      assert_equal [], result[:readings]
      assert_equal [], result[:components]
    end

    def test_missing_optional_fields
      minimal_subject = [{
        'id' => 999,
        'object' => 'radical',
        'data' => {
          'characters' => nil,
          'level' => 5,
          'slug' => 'test',
          'document_url' => 'https://example.com',
          'meanings' => [
            { 'meaning' => 'Test', 'primary' => true, 'accepted_answer' => true }
          ],
          # No amalgamation_subject_ids, no mnemonics
          # Adding empty arrays to prevent nil errors
          'amalgamation_subject_ids' => []
        }
      }]

      result = DataNormalizer.subjects(minimal_subject)

      subject = result[:subjects][0]
      assert_equal [999, nil, 5, 'radical', 'test', 'https://example.com', nil, nil, nil], subject
      assert_equal [], result[:components]
    end

    def test_boolean_conversions
      subject_data = [{
        'id' => 123,
        'object' => 'kanji',
        'data' => {
          'characters' => '本',
          'level' => 1,
          'slug' => 'book',
          'document_url' => 'https://example.com',
          'meanings' => [
            { 'meaning' => 'Book', 'primary' => true, 'accepted_answer' => false },
            { 'meaning' => 'Origin', 'primary' => false, 'accepted_answer' => true }
          ],
          'readings' => [
            { 'reading' => 'ほん', 'primary' => false, 'accepted_answer' => false, 'type' => 'kunyomi' }
          ],
          'component_subject_ids' => [],
          'amalgamation_subject_ids' => []
        }
      }]

      result = DataNormalizer.subjects(subject_data)

      # Test boolean to integer conversion for meanings
      assert_equal [123, 'Book', 1, 0], result[:meanings][0]    # primary: true, accepted: false
      assert_equal [123, 'Origin', 0, 1], result[:meanings][1]  # primary: false, accepted: true

      # Test boolean to integer conversion for readings
      assert_equal [123, 'ほん', 0, 0, 'kunyomi'], result[:readings][0] # primary: false, accepted: false
    end

    def test_assignments_normalization
      assignment_data = [
        {
          'id' => 80463006,
          'object' => 'assignment',
          'data' => {
            'subject_id' => 440,
            'srs_stage' => 5,
            'hidden' => false,
            'available_at' => '2017-09-05T23:04:00.000000Z',
            'started_at' => '2017-08-30T23:04:00.000000Z',
            'unlocked_at' => '2017-08-30T23:04:00.000000Z'
          }
        },
        {
          'id' => 80463007,
          'object' => 'assignment',
          'data' => {
            'subject_id' => 441,
            'srs_stage' => 8,
            'hidden' => true,
            'available_at' => nil,
            'started_at' => nil,
            'unlocked_at' => nil
          }
        }
      ]

      result = DataNormalizer.assignments(assignment_data)

      assert_equal 2, result.length

      # Test first assignment
      first_assignment = result[0]
      assert_equal [80463006, 440, 5, 0, '2017-09-05T23:04:00.000000Z', '2017-08-30T23:04:00.000000Z', '2017-08-30T23:04:00.000000Z'], first_assignment

      # Test second assignment with null values and hidden=true
      second_assignment = result[1]
      assert_equal [80463007, 441, 8, 1, nil, nil, nil], second_assignment
    end

    def test_unite_method
      subjects_hash = {
        subjects: [[1, 'char', 1, 'radical', 'slug', 'url', nil, 'mnemonic']],
        meanings: [[1, 'meaning', 1, 1]],
        readings: [],
        components: []
      }

      assignments = [[123, 1, 5, 0, nil, nil]]

      result = DataNormalizer.unite!(subjects_hash, assignments)

      assert_equal subjects_hash.object_id, result.object_id # Should modify original hash
      assert_equal assignments, result[:assignments]
      assert result.key?(:assignments)
      assert result.key?(:subjects)
      assert result.key?(:meanings)
      assert result.key?(:readings)
      assert result.key?(:components)
    end

    def test_multiple_subjects_mixed_types
      mixed_data = [
        {
          'id' => 1,
          'object' => 'radical',
          'data' => {
            'characters' => '一',
            'level' => 1,
            'slug' => 'ground',
            'document_url' => 'https://www.wanikani.com/radicals/ground',
            'meanings' => [{ 'meaning' => 'Ground', 'primary' => true, 'accepted_answer' => true }],
            'amalgamation_subject_ids' => [440],
            'meaning_mnemonic' => 'This is the ground'
          }
        },
        {
          'id' => 440,
          'object' => 'kanji',
          'data' => {
            'characters' => '人',
            'level' => 1,
            'slug' => 'person',
            'document_url' => 'https://www.wanikani.com/kanji/person',
            'meanings' => [{ 'meaning' => 'Person', 'primary' => true, 'accepted_answer' => true }],
            'readings' => [{ 'reading' => 'じん', 'primary' => true, 'accepted_answer' => true, 'type' => 'onyomi' }],
            'component_subject_ids' => [1],
            'amalgamation_subject_ids' => [2467],
            'meaning_mnemonic' => 'Person mnemonic',
            'reading_mnemonic' => 'Reading mnemonic'
          }
        }
      ]

      result = DataNormalizer.subjects(mixed_data)

      # Should have 2 subjects
      assert_equal 2, result[:subjects].length

      # Should have 2 meanings (one per subject)
      assert_equal 2, result[:meanings].length

      # Should have 1 reading (only kanji has readings)
      assert_equal 1, result[:readings].length

      # Should have 2 component relationships
      assert_equal 2, result[:components].length
      assert_equal [1, 440], result[:components][0]  # radical -> kanji
      assert_equal [440, 2467], result[:components][1] # kanji -> vocab
    end
  end
end
