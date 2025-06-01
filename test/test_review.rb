# frozen_string_literal: true
# rubocop: disable all

require 'minitest/autorun'
require 'fileutils'
require 'time'
require_relative '../lib/review'
require_relative '../lib/db/database'
require_relative '../lib/error/attempting_already_passed_subject_error'
require_relative '../lib/error/empty_buffer_error'

module WaniKaniTUI
  class TestReview < Minitest::Test
    TMP_DIR = File.expand_path('../tmp/WaniKaniTUI', __dir__)
    DB_PATH = File.join(TMP_DIR, 'db.sqlite3')

    def setup
      FileUtils.rm_f(DB_PATH)
      FileUtils.mkdir_p(TMP_DIR)
      ENV['XDG_DATA_HOME'] = TMP_DIR
      @db = Database.new
      setup_test_data
    end

    def teardown
      FileUtils.rm_rf(TMP_DIR)
    end

    # Initialization tests
    def test_initialization_with_no_available_reviews
      review = Review.new(@db)
      assert_raises(EmptyBufferError) { review.peek }
    end

    def test_initialization_with_available_reviews
      create_available_assignment(1, 1, Time.now.utc.iso8601)
      review = Review.new(@db)

      assert_equal [1, 1], review.peek
    end

    def test_initialization_auto_passes_radical_readings
      create_available_assignment(1, 1, Time.now.utc.iso8601, 'radical')
      review = Review.new(@db)

      assert review.reading_passed?
    end

    def test_initialization_auto_passes_kana_vocabulary_readings
      create_available_assignment(1, 1, Time.now.utc.iso8601, 'kana_vocabulary')
      review = Review.new(@db)

      assert review.reading_passed?
    end

    def test_initialization_does_not_auto_pass_kanji_readings
      create_available_assignment(1, 1, Time.now.utc.iso8601, 'kanji')
      review = Review.new(@db)

      refute review.reading_passed?
    end

    def test_initialization_does_not_auto_pass_vocabulary_readings
      create_available_assignment(1, 1, Time.now.utc.iso8601, 'vocabulary')
      review = Review.new(@db)

      refute review.reading_passed?
    end

    # Peek tests
    def test_peek_raises_error_when_buffer_empty
      review = Review.new(@db)
      assert_raises(EmptyBufferError) { review.peek }
    end

    def test_peek_returns_first_buffer_item
      create_available_assignment(1, 1, Time.now.utc.iso8601)
      create_available_assignment(2, 2, Time.now.utc.iso8601)
      review = Review.new(@db)

      first_peek = review.peek
      second_peek = review.peek
      assert_equal first_peek, second_peek
    end

    # Reading tests
    def test_pass_reading_updates_database
      create_available_assignment(1, 2, Time.now.utc.iso8601, 'kanji')
      review = Review.new(@db)

      refute review.reading_passed?
      review.pass_reading
      assert review.reading_passed?
    end

    def test_pass_reading_raises_error_if_already_passed
      create_available_assignment(1, 1, Time.now.utc.iso8601, 'radical')
      review = Review.new(@db)

      assert_raises(AttemptingAlreadyPassedSubjectError) do
        review.pass_reading # radicals auto pass readings on buffer entry
      end
    end

    def test_pass_reading_completes_review_if_meaning_also_passed
      create_available_assignment(1, 2, Time.now.utc.iso8601, 'kanji')
      review = Review.new(@db)

      review.pass_meaning
      review.pass_reading

      assert_raises(EmptyBufferError) { review.peek }
      review_record = @db.execute('SELECT created_at FROM review WHERE assignment_id = 1').first
      refute_nil review_record[0]
    end

    def test_pass_reading_rotates_buffer_if_meaning_not_passed
      create_available_assignment(1, 2, Time.now.utc.iso8601, 'kanji')  # Use kanji
      create_available_assignment(2, 6, Time.now.utc.iso8601, 'kanji')  # Use kanji
      review = Review.new(@db)

      first_assignment = review.peek[0]
      review.pass_reading
      second_assignment = review.peek[0]

      refute_equal first_assignment, second_assignment
    end

    def test_fail_reading_increments_incorrect_count
      create_available_assignment(1, 2, Time.now.utc.iso8601, 'kanji')
      review = Review.new(@db)

      assert_equal 0, review.incorrect_reading_answers_count
      review.fail_reading
      assert_equal 1, review.incorrect_reading_answers_count
    end

    def test_fail_reading_raises_error_if_already_passed
      create_available_assignment(1, 1, Time.now.utc.iso8601, 'radical')
      review = Review.new(@db)

      assert_raises(AttemptingAlreadyPassedSubjectError) do
        review.fail_reading # radicals auto pass readings
      end
    end

    def test_fail_reading_rotates_buffer
      create_available_assignment(1, 2, Time.now.utc.iso8601, 'kanji')
      create_available_assignment(2, 6, Time.now.utc.iso8601, 'kanji')
      review = Review.new(@db)

      first_assignment = review.peek[0]
      review.fail_reading
      second_assignment = review.peek[0]

      refute_equal first_assignment, second_assignment
    end

    def test_multiple_fail_meaning_increments_count
      create_available_assignment(1, 2, Time.now.utc.iso8601, 'kanji')
      review = Review.new(@db)

      assert_equal 0, review.incorrect_meaning_answers_count
      review.fail_meaning
      assert_equal 1, review.incorrect_meaning_answers_count
      review.fail_meaning
      assert_equal 2, review.incorrect_meaning_answers_count
    end

    # Meaning tests
    def test_pass_meaning_updates_database
      create_available_assignment(1, 2, Time.now.utc.iso8601, 'kanji')
      review = Review.new(@db)

      refute review.meaning_passed?
      review.pass_meaning
      assert review.meaning_passed?
    end

    def test_pass_meaning_raises_error_if_already_passed
      create_available_assignment(1, 2, Time.now.utc.iso8601, 'kanji')
      review = Review.new(@db)

      review.pass_meaning
      assert_raises(AttemptingAlreadyPassedSubjectError) do
        review.pass_meaning
      end
    end

    def test_pass_meaning_completes_review_if_reading_also_passed
      create_available_assignment(1, 1, Time.now.utc.iso8601, 'radical')
      review = Review.new(@db)

      review.pass_meaning # radicals auto pass reading on buffer entry

      assert_raises(EmptyBufferError) { review.peek }
      review_record = @db.execute('SELECT created_at FROM review WHERE assignment_id = 1').first
      refute_nil review_record[0]
    end

    def test_pass_meaning_rotates_buffer_if_reading_not_passed
      create_available_assignment(1, 2, Time.now.utc.iso8601, 'kanji')
      create_available_assignment(2, 6, Time.now.utc.iso8601, 'kanji')
      review = Review.new(@db)

      first_assignment = review.peek[0]
      review.pass_meaning
      second_assignment = review.peek[0]

      refute_equal first_assignment, second_assignment
    end

    def test_fail_meaning_increments_incorrect_count
      create_available_assignment(1, 2, Time.now.utc.iso8601, 'kanji')
      review = Review.new(@db)

      assert_equal 0, review.incorrect_meaning_answers_count
      review.fail_meaning
      assert_equal 1, review.incorrect_meaning_answers_count
    end

    def test_fail_meaning_raises_error_if_already_passed
      create_available_assignment(1, 2, Time.now.utc.iso8601, 'kanji')
      review = Review.new(@db)

      review.pass_meaning
      assert_raises(AttemptingAlreadyPassedSubjectError) do
        review.fail_meaning
      end
    end

    def test_fail_meaning_rotates_buffer
      create_available_assignment(1, 2, Time.now.utc.iso8601, 'kanji')
      create_available_assignment(2, 6, Time.now.utc.iso8601, 'kanji')
      review = Review.new(@db)

      first_assignment = review.peek[0]
      review.fail_meaning
      second_assignment = review.peek[0]

      refute_equal first_assignment, second_assignment
    end

    def test_fail_meaning_on_single_assignment_rotates_correctly
      create_available_assignment(1, 2, Time.now.utc.iso8601, 'kanji')
      review = Review.new(@db)

      assignment_id = review.peek[0]
      review.fail_meaning

      assert_equal assignment_id, review.peek[0]
      assert_equal 1, review.incorrect_meaning_answers_count
    end

    # Buffer management tests
    def test_buffer_size_respects_constant
      # Create more assignments than buffer size
      (1..REVIEW_BUFFER_SIZE + 5).each do |i|
        subject_id = ((i - 1) % 20) + 1  # Use existing subjects
        create_available_assignment(i, subject_id, Time.now.utc.iso8601, 'kanji')
      end

      review = Review.new(@db)
      buffer_assignments = []

      # Collect all assignments in buffer by rotating through them
      REVIEW_BUFFER_SIZE.times do
        buffer_assignments << review.peek[0]
        review.fail_meaning  # Rotate to next
      end

      # Should cycle back to first
      assert_equal buffer_assignments[0], review.peek[0]
      assert_equal REVIEW_BUFFER_SIZE, buffer_assignments.uniq.length
    end

    def test_buffer_refills_when_reviews_completed
      create_available_assignment(1, 1, Time.now.utc.iso8601, 'radical')
      create_available_assignment(2, 5, Time.now.utc.iso8601, 'radical')

      review = Review.new(@db)

      review.pass_meaning

      begin
        second_assignment = review.peek[0]
        assert [1, 2].include?(second_assignment)
      rescue EmptyBufferError
        flunk "Buffer should have refilled with second assignment"
      end
    end

    def test_unavailable_assignments_not_included
      future_time = (Time.now + 3600).utc.iso8601
      create_available_assignment(1, 1, future_time)

      review = Review.new(@db)
      assert_raises(EmptyBufferError) { review.peek }
    end

    def test_unstarted_assignments_not_included
      create_assignment_without_start(1, 1, Time.now.utc.iso8601)

      review = Review.new(@db)
      assert_raises(EmptyBufferError) { review.peek }
    end

    def test_completed_reviews_not_included_in_buffer
      create_available_assignment(1, 1, Time.now.utc.iso8601, 'radical')
      review = Review.new(@db)

      # Complete the review
      review.pass_meaning

      # Create new review instance - should have empty buffer
      new_review = Review.new(@db)
      assert_raises(EmptyBufferError) { new_review.peek }
    end

    # Edge cases
    def test_handles_null_incorrect_counts
      create_available_assignment(1, 2, Time.now.utc.iso8601, 'kanji')
      review = Review.new(@db)

      @db.execute('UPDATE review SET incorrect_reading_answers = NULL, incorrect_meaning_answers = NULL WHERE assignment_id = 1')

      assert_equal 0, review.incorrect_reading_answers_count
      assert_equal 0, review.incorrect_meaning_answers_count
    end

    def test_review_table_population_is_idempotent
      create_available_assignment(1, 2, Time.now.utc.iso8601, 'kanji')

      # Create review instance twice
      Review.new(@db)
      Review.new(@db)

      # Should only have one review record
      review_count = @db.execute('SELECT COUNT(*) FROM review').first[0]
      assert_equal 1, review_count
    end

    def test_reading_and_meaning_status_independent
      create_available_assignment(1, 2, Time.now.utc.iso8601, 'kanji')
      review = Review.new(@db)

      review.pass_reading
      assert review.reading_passed?
      refute review.meaning_passed?
    end

    def test_meaning_passed_reading_not_passed
      create_available_assignment(1, 2, Time.now.utc.iso8601, 'kanji')
      review = Review.new(@db)

      review.pass_meaning
      refute review.reading_passed?
      assert review.meaning_passed?
    end

    def test_mixed_subject_types_in_buffer
      create_available_assignment(1, 1, Time.now.utc.iso8601, 'radical')
      create_available_assignment(2, 2, Time.now.utc.iso8601, 'kanji')
      create_available_assignment(3, 7, Time.now.utc.iso8601, 'vocabulary')
      create_available_assignment(4, 4, Time.now.utc.iso8601, 'kana_vocabulary')

      review = Review.new(@db)

      # Collect reading status for all items in buffer
      reading_statuses = {}
      4.times do |i|
        assignment_id = review.peek[0]
        reading_statuses[assignment_id] = review.reading_passed?
        review.fail_meaning
      end

      # Radicals and kana_vocabulary should have reading auto-passed
      assert reading_statuses[1], 'Radical should have reading auto-passed'
      refute reading_statuses[2], 'Kanji should not have reading auto-passed'
      refute reading_statuses[3], 'Vocabulary should not have reading auto-passed'
      assert reading_statuses[4], 'Kana vocabulary should have reading auto-passed'
    end

    private

    def setup_test_data
      (1..20).each do |i|
        object_type = case i % 4
                     when 1 then 'radical'
                     when 2 then 'kanji'
                     when 3 then 'vocabulary'
                     when 0 then 'kana_vocabulary'
                     end
        @db.execute("INSERT INTO subject (id, characters, level, object, slug, url) VALUES (?, ?, ?, ?, ?, ?)",
                    [i, "字#{i}", 1, object_type, "slug#{i}", "https://example.com/#{i}"])
      end
    end

    def create_available_assignment(assignment_id, subject_id, available_at, subject_type = nil)
      if subject_type
        @db.execute("UPDATE subject SET object = ? WHERE id = ?", [subject_type, subject_id])
      end

      @db.execute(
        "INSERT INTO assignment (assignment_id, subject_id, srs, hidden, available_at, started_at) VALUES (?, ?, ?, ?, ?, ?)",
        [assignment_id, subject_id, 4, 0, available_at, Time.now.utc.iso8601]
      )
    end

    def create_assignment_without_start(assignment_id, subject_id, available_at)
      @db.execute(
        "INSERT INTO assignment (assignment_id, subject_id, srs, hidden, available_at, started_at) VALUES (?, ?, ?, ?, ?, ?)",
        [assignment_id, subject_id, 4, 0, available_at, nil]
      )
    end
  end
end
