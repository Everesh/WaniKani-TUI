# frozen_string_literal: true
# rubocop: disable all

require 'minitest/autorun'
require 'fileutils'
require 'time'

require_relative '../lib/db/database'
require_relative '../lib/db/common_query'

module WaniKaniTUI
  class TestCommonQuery < Minitest::Test
    TMP_DIR = File.expand_path('../tmp/test_common_query', __dir__)
    DB_PATH = File.join(TMP_DIR, Database::DB_FILE_NAME)

    def setup
      FileUtils.rm_f(DB_PATH)
      FileUtils.mkdir_p(TMP_DIR)
      ENV['XDG_DATA_HOME'] = TMP_DIR
      @db = Database.new(force_db_regen: true)
      @query = CommonQuery.new(@db)
    end


    def teardown
      FileUtils.rm_rf(TMP_DIR)
    end

    def test_get_subject_by_id
      create_subject(1, 1, 'radical', 'ground', 'url1', characters: '一')
      create_subject(2, 1, 'radical', 'two', 'url2', characters: '二')

      subject = @query.get_subject_by_id(1)
      assert_equal [1, '一', 1, 'radical', 'ground', 'url1', nil, nil, nil], subject

      subject = @query.get_subject_by_id(99) # Non-existent ID
      assert_nil subject
    end


    def test_get_subject_by_id_as_hash
      create_subject(1, 1, 'radical', 'ground', 'url1', characters: '一')

      subject_hash = @query.get_subject_by_id_as_hash(1)
      assert_instance_of Hash, subject_hash
      assert_equal 1, subject_hash['id']
      assert_equal '一', subject_hash['characters']
    end

    def test_get_components_by_id
      create_subject(1, 1, 'radical', 'ground', 'url1', characters: '一')
      create_subject(2, 1, 'kanji', 'two', 'url2', characters: '二')
      create_subject(3, 1, 'kanji', 'three', 'url3', characters: '三')

      create_component(1, 3) # 一 is a component of 三
      create_component(2, 3) # 二 is a component of 三

      components = @query.get_components_by_id(3)
      assert_equal 2, components.length
      assert_includes components.map { |c| c[0] }, 1 # Check component IDs are present
      assert_includes components.map { |c| c[0] }, 2

      components = @query.get_components_by_id(1) # Subject with no components
      assert_equal [], components
    end


    def test_get_components_by_id_as_hash
      create_subject(1, 1, 'radical', 'ground', 'url1', characters: '一')
      create_subject(3, 1, 'kanji', 'three', 'url3', characters: '三')
      create_component(1, 3)

      components_hash = @query.get_components_by_id_as_hash(3)
      assert_instance_of Array, components_hash
      assert_equal 1, components_hash.length
      assert_instance_of Hash, components_hash.first
      assert_equal 1, components_hash.first['id']
      assert_equal '一', components_hash.first['characters']
    end

    def test_get_amalgamations_by_id
      create_subject(1, 1, 'radical', 'ground', 'url1', characters: '一')
      create_subject(3, 1, 'kanji', 'one', 'url3', characters: '一')
      create_subject(4, 1, 'vocabulary', 'hitori', 'url4', characters: '一人')

      create_component(1, 3) # 一 is component of 一
      create_component(3, 4) # 一 is component of 一人

      amalgamations = @query.get_amalgamations_by_id(3) # Subjects that use 一 as a component
      assert_equal 1, amalgamations.length
      assert_equal 4, amalgamations.first[0] # Check amalgamation ID is present

      amalgamations = @query.get_amalgamations_by_id(4) # Subject that is not a component of anything
      assert_equal [], amalgamations
    end


    def test_get_amalgamations_by_id_as_hash
      create_subject(3, 1, 'kanji', 'person', 'url3', characters: '人')
      create_subject(4, 1, 'vocabulary', 'alone', 'url4', characters: '一人')
      create_component(3, 4)

      amalgamations_hash = @query.get_amalgamations_by_id_as_hash(3)
      assert_instance_of Array, amalgamations_hash
      assert_equal 1, amalgamations_hash.length
      assert_instance_of Hash, amalgamations_hash.first
      assert_equal 4, amalgamations_hash.first['id']
      assert_equal '一人', amalgamations_hash.first['characters']
    end

    def test_get_readings_by_id
      create_subject(1, 1, 'kanji', 'person', 'url3', characters: '人')
      create_subject(3, 1, 'kanji', 'person', 'url3', characters: '人')
      create_reading(3, 'じん', true, true, 'onyomi')
      create_reading(3, 'にん', false, true, 'onyomi')
      create_reading(3, 'ひと', true, true, 'kunyomi')

      readings = @query.get_readings_by_id(3)
      assert_equal 3, readings.length
      assert_includes readings.map { |r| r[1] }, 'じん'
      assert_includes readings.map { |r| r[1] }, 'にん'
      assert_includes readings.map { |r| r[1] }, 'ひと'

      readings = @query.get_readings_by_id(1) # Subject with no readings
      assert_equal [], readings
    end


    def test_get_readings_by_id_as_hash
      create_subject(3, 1, 'kanji', 'person', 'url3', characters: '人')
      create_reading(3, 'じん', true, true, 'onyomi')

      readings_hash = @query.get_readings_by_id_as_hash(3)
      assert_instance_of Array, readings_hash
      assert_equal 1, readings_hash.length
      assert_instance_of Hash, readings_hash.first
      assert_equal 3, readings_hash.first['id']
      assert_equal 'じん', readings_hash.first['reading']
    end

    def test_get_meanings_by_id
      create_subject(1, 1, 'radical', 'ground', 'url1', characters: '一')
      create_subject(99, 1, 'radical', 'ground', 'url1', characters: '一')
      create_meaning(1, 'Ground', true, true)
      create_meaning(1, 'Floor', false, true)

      meanings = @query.get_meanings_by_id(1)
      assert_equal 2, meanings.length
      assert_includes meanings.map { |m| m[1] }, 'Ground'
      assert_includes meanings.map { |m| m[1] }, 'Floor'

      meanings = @query.get_meanings_by_id(99) # Subject with no meanings
      assert_equal [], meanings
    end


    def test_get_meanings_by_id_as_hash
      create_subject(1, 1, 'radical', 'ground', 'url1', characters: '一')
      create_meaning(1, 'Ground', true, true)

      meanings_hash = @query.get_meanings_by_id_as_hash(1)
      assert_instance_of Array, meanings_hash
      assert_equal 1, meanings_hash.length
      assert_instance_of Hash, meanings_hash.first
      assert_equal 1, meanings_hash.first['id']
      assert_equal 'Ground', meanings_hash.first['meaning']
    end

    def test_get_assignment_by_assignment_id
      create_subject(1, 1, 'radical', 'ground', 'url1', characters: '一')
      create_assignment(100, 1, 5, false, Time.now.to_s, Time.now.to_s)
      create_assignment(101, 1, 0, true, nil, nil)

      assignment = @query.get_assignment_by_assignment_id(100)
      assert_equal 100, assignment[0]
      assert_equal 1, assignment[1]

      assignment = @query.get_assignment_by_assignment_id(999) # Non-existent ID
      assert_nil assignment
    end


    def test_get_assignment_by_assignment_id_as_hash
      create_subject(1, 1, 'radical', 'ground', 'url1', characters: '一')
      create_assignment(100, 1, 5, false, Time.now.to_s, Time.now.to_s)

      assignment_hash = @query.get_assignment_by_assignment_id_as_hash(100)
      assert_instance_of Hash, assignment_hash
      assert_equal 100, assignment_hash['assignment_id']
      assert_equal 1, assignment_hash['subject_id']
    end

    def test_get_assignment_by_subject_id
      create_subject(1, 1, 'radical', 'ground', 'url1', characters: '一')
      create_subject(2, 1, 'radical', 'two', 'url2', characters: '二')
      create_assignment(100, 1, 5, false, Time.now.to_s, Time.now.to_s)
      create_assignment(101, 2, 0, true, nil, nil)

      assignment = @query.get_assignment_by_subject_id(1)
      assert_equal 100, assignment[0]
      assert_equal 1, assignment[1]

      assignment = @query.get_assignment_by_subject_id(99) # Non-existent subject ID
      assert_nil assignment
    end

    def test_get_assignment_by_subject_id_as_hash
      create_subject(1, 1, 'radical', 'ground', 'url1', characters: '一')
      create_assignment(100, 1, 5, false, Time.now.to_s, Time.now.to_s)

      assignment_hash = @query.get_assignment_by_subject_id_as_hash(1)
      assert_instance_of Hash, assignment_hash
      assert_equal 100, assignment_hash['assignment_id']
      assert_equal 1, assignment_hash['subject_id']
    end

    def test_initialization_raises_error_for_invalid_db
      invalid_db = Object.new
      assert_raises(ArgumentError, 'Expected a WaniKaniTUI::Database instance') do
        CommonQuery.new(invalid_db)
      end
    end

    private

    # Helper methods to insert data
    def create_subject(id, level, object, slug, url, characters: nil, mnemonic_reading: nil, mnemonic_meaning: nil, hidden_at: nil)
      @db.execute(
        "INSERT INTO subject (id, characters, level, object, slug, url, mnemonic_reading, mnemonic_meaning, hidden_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [id, characters, level, object, slug, url, mnemonic_reading, mnemonic_meaning, hidden_at]
      )
    end


    def create_component(id_component, id_product)
      @db.execute(
        "INSERT INTO components (id_component, id_product) VALUES (?, ?)",
        [id_component, id_product]
      )
    end


    def create_reading(id, reading, primary, accepted, type = nil)
      @db.execute(
        "INSERT INTO subject_reading (id, reading, \"primary\", accepted, type) VALUES (?, ?, ?, ?, ?)",
        [id, reading, primary ? 1 : 0, accepted ? 1 : 0, type]
      )
    end


    def create_meaning(id, meaning, primary, accepted)
      @db.execute(
        "INSERT INTO subject_meaning (id, meaning, \"primary\", accepted) VALUES (?, ?, ?, ?)",
        [id, meaning, primary ? 1 : 0, accepted ? 1 : 0]
      )
    end


    def create_assignment(assignment_id, subject_id, srs, hidden, available_at, started_at, unlocked_at: nil)
      @db.execute(
        "INSERT INTO assignment (assignment_id, subject_id, srs, hidden, available_at, started_at, unlocked_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
        [assignment_id, subject_id, srs, hidden ? 1 : 0, available_at, started_at, unlocked_at]
      )
    end
  end
end
