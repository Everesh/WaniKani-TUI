# frozen_string_literal: true

# rubocop: disable Metrics/ClassLength

require 'time'

require_relative 'db/database'
require_relative 'error/attempting_already_passed_subject_error'
require_relative 'error/empty_buffer_error'

module WaniKaniTUI
  # Manages reviews: queue, buffer and the review db table
  class Review
    DEFAULT_BUFFER_SIZE = 5

    def initialize(db, buffer_size: DEFAULT_BUFFER_SIZE)
      @db = db
      @buffer = []
      @buffer_size = buffer_size
      update_review_table!
      update_buffer!
    end

    # [id_assignment, id_subject]
    def peek
      raise EmptyBufferError if @buffer.empty?

      @buffer.first
    end

    def peek_as_hash
      raise EmptyBufferError if @buffer.empty?

      item = @buffer.first
      { assignment_id: item.first, subject_id: item.last }
    end

    def peek_last
      raise EmptyBufferError if @buffer.empty?

      @buffer.last
    end

    def peek_last_as_hash
      raise EmptyBufferError if @buffer.empty?

      item = @buffer.last
      { assignment_id: item.first, subject_id: item.last }
    end

    def pass_reading!
      raise AttemptingAlreadyPassedSubjectError, 'Cannot pass reading: already marked as passed!' if reading_passed?

      @db.execute('UPDATE review SET reading_passed = 1 WHERE assignment_id = ?', [peek.first])

      meaning_passed? ? complete_review! : @buffer.rotate!
    end

    def fail_reading!
      raise AttemptingAlreadyPassedSubjectError, 'Cannot fail reading: already marked as passed!' if reading_passed?

      @db.execute(
        'UPDATE review SET incorrect_reading_answers = ? WHERE assignment_id = ?',
        [incorrect_reading_answers_count + 1, peek.first]
      )
      @buffer.rotate!
    end

    def reading_passed?
      column_value('reading_passed') == 1
    end

    def incorrect_reading_answers_count
      column_value('incorrect_reading_answers') || 0
    end

    def pass_meaning!
      raise AttemptingAlreadyPassedSubjectError, 'Cannot pass meaning: already marked as passed!' if meaning_passed?

      @db.execute('UPDATE review SET meaning_passed = 1 WHERE assignment_id = ?', [peek.first])

      reading_passed? ? complete_review! : @buffer.rotate!
    end

    def fail_meaning!
      raise AttemptingAlreadyPassedSubjectError, 'Cannot fail meaning: already marked as passed!' if meaning_passed?

      @db.execute(
        'UPDATE review SET incorrect_meaning_answers = ? WHERE assignment_id = ?',
        [incorrect_meaning_answers_count + 1, peek.first]
      )
      @buffer.rotate!
    end

    def meaning_passed?
      column_value('meaning_passed') == 1
    end

    def incorrect_meaning_answers_count
      column_value('incorrect_meaning_answers') || 0
    end

    def update_review_table!
      available_reviews = @db.execute(
        "SELECT assignment_id
         FROM assignment
         WHERE started_at IS NOT NULL
         AND available_at <= ?", [Time.now.utc.iso8601]
      )
      populate_review(available_reviews)
      pass_radical_readings!
      pass_kana_vocab_readings!
    end

    private

    def complete_review!
      @db.execute(
        'UPDATE review SET created_at = ? WHERE assignment_id = ?',
        [Time.now.utc.iso8601, peek.first]
      )
      @buffer.shift
      update_buffer!
    end

    def column_value(column)
      @db.execute(
        "SELECT #{column} FROM review WHERE assignment_id = ?", [peek.first]
      ).flatten.first
    end

    def populate_review(assignment_ids)
      @db.transaction do
        assignment_ids.each do |(assignment_id)|
          @db.execute(
            "INSERT OR IGNORE INTO review (assignment_id, meaning_passed, reading_passed)
             VALUES (?, ?, ?)", [assignment_id, 0, 0]
          )
        end
      end
    end

    def pass_radical_readings!
      pass_readings!(@db.execute(
                       "SELECT r.assignment_id
                       FROM review r
                       JOIN assignment a ON r.assignment_id = a.assignment_id
                       JOIN subject s ON s.id = a.subject_id
                       WHERE s.object='radical'"
                     ))
    end

    def pass_kana_vocab_readings!
      pass_readings!(@db.execute(
                       "SELECT r.assignment_id
                        FROM review r
                        JOIN assignment a ON r.assignment_id = a.assignment_id
                        JOIN subject s ON s.id = a.subject_id
                        WHERE s.object='kana_vocabulary'"
                     ))
    end

    def pass_readings!(assignment_ids)
      @db.transaction do
        assignment_ids.each do |(assignment_id)|
          @db.execute('UPDATE review SET reading_passed = 1 WHERE assignment_id = ?', [assignment_id])
        end
      end
    end

    def update_buffer!
      return if @buffer.length >= @buffer_size

      @buffer.concat(@db.execute(
                       "SELECT r.assignment_id, s.id
                        FROM review r
                        JOIN assignment a ON r.assignment_id = a.assignment_id
                        JOIN subject s ON s.id = a.subject_id
                        WHERE NOT (r.meaning_passed = 1 AND r.reading_passed = 1)
                        ORDER BY RANDOM()
                        LIMIT ?", [@buffer_size - @buffer.length]
                     ))
    end
  end
end

# rubocop: enable Metrics/ClassLength
