# frozen_string_literal: true

# rubocop: disable Metrics/ClassLength

require 'time'

require_relative 'database'

module WaniKaniTUI
  # Provides common db query methods
  class CommonQuery
    def initialize(db)
      raise ArgumentError, 'Expected a WaniKaniTUI::Database instance' unless db.is_a?(WaniKaniTUI::Database)

      @db = db
    end

    def get_subject_by_id(id)
      @db.get_first_row(
        "SELECT *
         FROM subject
         WHERE id = ?", [id]
      )
    end

    def get_components_by_id(id)
      @db.execute(
        "SELECT s.*
         FROM components c
         JOIN subject s ON s.id = c.id_component
         WHERE c.id_product = ?", [id]
      )
    end

    def get_amalgamations_by_id(id)
      @db.execute(
        "SELECT s.*
         FROM components c
         JOIN subject s ON s.id = c.id_product
         WHERE c.id_component = ?", [id]
      )
    end

    def get_readings_by_id(id)
      @db.execute(
        "SELECT *
         FROM subject_reading
         WHERE id = ?", [id]
      )
    end

    def get_meanings_by_id(id)
      @db.execute(
        "SELECT *
         FROM subject_meaning
         WHERE id = ?", [id]
      )
    end

    def get_assignment_by_assignment_id(id)
      @db.get_first_row(
        "SELECT *
         FROM assignment
         WHERE assignment_id = ?", [id]
      )
    end

    def get_assignment_by_subject_id(id)
      @db.get_first_row(
        "SELECT *
         FROM assignment
         WHERE subject_id = ?", [id]
      )
    end

    def get_review_by_assignment_id(id)
      @db.get_first_row(
        "SELECT *
         FROM review
         WHERE assignment_id = ?", [id]
      )
    end

    def get_lesson_by_assignment_id(id)
      @db.get_first_row(
        "SELECT *
         FROM lesson
         WHERE assignment_id = ?", [id]
      )
    end

    def count_available_reviews
      @db.get_first_row(
        "SELECT COUNT(*)
         FROM assignment
         WHERE available_at <= ?
         AND started_at IS NOT NULL", [Time.now.utc.iso8601]
      ).first
    end

    def count_pending_review_reports
      @db.get_first_row(
        "SELECT COUNT(*)
         FROM review
         WHERE meaning_passed = 1
         AND reading_passed = 1"
      ).first
    end

    def count_available_lessons
      @db.get_first_row(
        "SELECT COUNT(*)
         FROM assignment
         WHERE available_at <= ?
         AND started_at IS NULL", [Time.now.utc.iso8601]
      )
    end

    def count_pending_lesson_reports
      @db.get_first_row(
        "SELECT COUNT(*)
         FROM lesson"
      ).first
    end

    # rubocop: disable Naming/AccessorMethodName
    def get_last_sync_time
      @db.get_first_row(
        "SELECT value
         FROM meta
         WHERE key = 'updated_after'"
      ).first
    rescue NoMethodError # ~ if no record found
      nil
    end
    # rubocop: enable Naming/AccessorMethodName

    # Provides *_as_hash suffixed methods that return hashes instead of arrays
    def self.define_as_hash_variant(method_name)
      define_method("#{method_name}_as_hash") do |id|
        @db.results_as_hash = true
        send(method_name, id)
      ensure
        @db.results_as_hash = false
      end
    end

    define_as_hash_variant :get_subject_by_id
    define_as_hash_variant :get_components_by_id
    define_as_hash_variant :get_amalgamations_by_id
    define_as_hash_variant :get_readings_by_id
    define_as_hash_variant :get_meanings_by_id
    define_as_hash_variant :get_assignment_by_assignment_id
    define_as_hash_variant :get_assignment_by_subject_id
    define_as_hash_variant :get_review_by_assignment_id
    define_as_hash_variant :get_lesson_by_assignment_id
  end
end

# rubocop: enable Metrics/ClassLength
