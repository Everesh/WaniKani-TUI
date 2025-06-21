# frozen_string_literal: true

require 'time'

require_relative 'db/database'
require_relative 'error/attempting_already_passed_subject_error'
require_relative 'error/empty_buffer_error'
require_relative 'error/already_seen_error'
require_relative 'error/not_yet_seen_error'

module WaniKaniTUI
  # Manages lessons: queue, buffer and the lesson db table
  class Lesson
    DEFAULT_BUFFER_SIZE = 5

    attr_reader :buffer_size

    def initialize(db, buffer_size: DEFAULT_BUFFER_SIZE)
      @db = db
      @buffer_size = buffer_size
      create_buffer!
    end

    def peek
      raise EmptyBufferError if @buffer.empty?

      @buffer.first
    end

    def peek_as_hash
      raise EmptyBufferError if @buffer.empty?

      {
        assignment_id: @buffer.first[0],
        subject_id: @buffer.first[1],
        meaning_passed: @buffer.first[2],
        reading_passed: @buffer.first[3],
        seen: @buffer.first[4]
      }
    end

    def seen!
      raise AlreadySeenError unless peek_as_hash[:seen].zero?

      @buffer.first[4] = 1
      @buffer.rotate!
    end

    def unsee!
      raise NotYetSeenError if @buffer.last.last.zero?

      @buffer.rotate!(-1)
      @buffer.first[4] = 0
    end


    def pass_meaning!
      raise AttemptingAlreadyPassedSubjectError, 'Cannot pass meaning: already marked as passed!' if meaning_passed?

      @buffer.first[2] = 1
      reading_passed? ? complete_lesson! : @buffer.rotate!
    end

    def meaning_passed?
      !peek_as_hash[:meaning_passed].zero?
    end

    def pass_reading!
      raise AttemptingAlreadyPassedSubjectError, 'Cannot pass reading: already marked as passed!' if reading_passed?

      @buffer.first[3] = 1
      meaning_passed? ? complete_lesson! : @buffer.rotate!
    end

    def reading_passed?
      !peek_as_hash[:reading_passed].zero?
    end

    def rotate!
      @buffer.rotate!
    end

    private

    # rubocop: disable Metrics/MethodLength
    def create_buffer!
      raw_rows = @db.execute(
        "SELECT a.assignment_id, s.id, 0 AS 'meaning_passed',
         CASE WHEN s.object IN ('kana_vocabulary', 'radical') THEN 1 ELSE 0 END AS 'reading_passed', 0 AS 'seen'
         FROM assignment a
         JOIN subject s
         ON a.subject_id = s.id
         WHERE a.started_at IS NULL
         AND a.hidden = 0
         AND s.hidden_at IS NULL
         AND a.unlocked_at IS NOT NULL
         AND a.assignment_id NOT IN (SELECT assignment_id FROM lesson)
         ORDER BY RANDOM()
         LIMIT ?", [@buffer_size]
      ) # [assignment_id, subject_id, meaning_passed?, reading_passed?, seen?]

      @buffer = raw_rows.map(&:dup)
    end
    # rubocop: enable Metrics/MethodLength

    def complete_lesson!
      @db.execute(
        "INSERT OR REPLACE INTO lesson (assignment_id, started_at)
        VALUES (?, ?)", [peek_as_hash[:assignment_id], Time.now.utc.iso8601]
      )
      @buffer.shift
      create_buffer! if @buffer.empty?
    end
  end
end
