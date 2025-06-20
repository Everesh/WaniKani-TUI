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

    # rubocop: disable Naming/AccessorMethodName
    def get_all_passed_reviews
      @db.execute(
        "SELECT *
         FROM review
         WHERE created_at IS NOT NULL"
      )
    end

    def get_all_passed_reviews_with_chars
      @db.execute(
        "SELECT r.*, s.characters, s.slug
         FROM review r
         JOIN assignment a
         ON a.assignment_id = r.assignment_id
         JOIN subject s
         on a.subject_id = s.id
         WHERE created_at IS NOT NULL"
      )
    end

    def get_all_passed_lessons
      @db.execute(
        "SELECT *
         FROM lesson
         WHERE started_at IS NOT NULL"
      )
    end

    def get_all_passed_lessons_with_chars
      @db.execute(
        "SELECT l.*, s.characters, s.slug
         FROM lesson l
         JOIN assignment a
         ON a.assignment_id = l.assignment_id
         JOIN subject s
         on a.subject_id = s.id
         WHERE l.started_at IS NOT NULL"
      )
    end
    # rubocop: enable Naming/AccessorMethodName

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

    # rubocop: disable Metrics/MethodLength
    def count_available_reviews
      @db.get_first_row(
        "SELECT COUNT(*)
         FROM assignment a
         JOIN subject s
         ON a.subject_id = s.id
         WHERE a.available_at <= ?
         AND a.started_at IS NOT NULL
         AND a.hidden = 0
         AND s.hidden_at IS NULL
         AND a.unlocked_at IS NOT NULL", [Time.now.utc.iso8601]
      ).first
    end
    # rubocop: enable Metrics/MethodLength

    def count_pending_review_reports
      @db.get_first_row(
        "SELECT COUNT(*)
         FROM review
         WHERE created_at IS NOT NULL"
      ).first
    end

    # rubocop: disable Metrics/MethodLength
    def count_available_lessons
      @db.get_first_row(
        "SELECT COUNT(*)
         FROM assignment a
         JOIN subject s
         ON a.subject_id = s.id
         WHERE a.started_at IS NULL
         AND a.hidden = 0
         AND s.level <= ?
         AND s.hidden_at IS NULL
         AND a.assignment_id NOT IN (SELECT assignment_id FROM lesson)
         AND a.unlocked_at IS NOT NULL", [get_user_level]
      ).first
    end
    # rubocop: enable Metrics/MethodLength

    def count_pending_lesson_reports
      @db.get_first_row(
        "SELECT COUNT(*)
         FROM lesson"
      ).first
    end

    # rubocop: disable Naming/AccessorMethodName
    def get_user_level
      @db.get_first_row(
        "SELECT value
         FROM meta
         WHERE key = 'user_level'"
      ).first
    rescue NoMethodError # ~ if no record found
      nil
    end
    # rubocop: enable Naming/AccessorMethodName

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

    def self.define_as_hash_variant_no_param(method_name)
      define_method("#{method_name}_as_hash") do
        @db.results_as_hash = true
        send(method_name)
      ensure
        @db.results_as_hash = false
      end
    end

    define_as_hash_variant_no_param :get_all_passed_reviews
    define_as_hash_variant_no_param :get_all_passed_reviews_with_chars
    define_as_hash_variant_no_param :get_all_passed_lessons
    define_as_hash_variant_no_param :get_all_passed_lessons_with_chars
  end
end

# rubocop: enable Metrics/ClassLength
