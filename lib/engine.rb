# frozen_string_literal: true

require 'time'

require_relative 'db/database'
require_relative 'wanikani_api'
require_relative 'util/data_normalizer'
require_relative 'db/persister'
require_relative 'review'
require_relative 'util/data_dir'
require_relative 'error/missing_api_key_error'
require_relative 'db/common_query'
require_relative 'util/payload_generator'

module WaniKaniTUI
  # Manages the core functionality of the application.
  class Engine
    attr_reader :common_query

    # rubocop: disable Metrics/MethodLength
    def initialize(force_db_regen: false, api_key: nil)
      if force_db_regen && api_key.nil?
        api_key = fetch_api_key # Attempts to carry over the previous API key to the new DB
        raise MissingApiKeyError, 'Could not fetch existing API key, new one is required' if api_key.nil?
      end

      @db = Database.new(force_db_regen: force_db_regen)
      @api = WaniKaniAPI.new(@db, api_key: api_key)
      @common_query = CommonQuery.new(@db)
      @preferences = DataDir.preferences
      custom_buffer_size = @preferences['buffer_size']
      @review = custom_buffer_size ? Review.new(@db, buffer_size: custom_buffer_size) : Review.new(@db)
      fetch!
    end
    # rubocop: enable Metrics/MethodLength

    # ==============
    # Review section
    # ==============

    # rubocop: disable Metrics/AbcSize
    def get_review(peek_at_last: false)
      peek = peek_at_last ? @review.peek_last_as_hash : @review.peek_as_hash
      review = @common_query.get_review_by_assignment_id_as_hash(peek[:assignment_id])
      assignment = @common_query.get_assignment_by_assignment_id_as_hash(peek[:assignment_id])
      subject = @common_query.get_subject_by_id_as_hash(peek[:subject_id])
      components = @common_query.get_components_by_id_as_hash(peek[:subject_id])
      amalgamations = @common_query.get_amalgamations_by_id_as_hash(peek[:subject_id])
      meanings = @common_query.get_meanings_by_id_as_hash(peek[:subject_id])
      readings = @common_query.get_readings_by_id_as_hash(peek[:subject_id])
      { review: review, assignment: assignment, subject: subject, readings: readings, meanings: meanings,
        components: components, amalgamations: amalgamations }
      # Return structured hash with all the relevant data from the front of the buffer
      # e.g {review: {}, assignment: {}, subject: {}, readings: [{},..], meanings: [{},..],
      #      components: [{},..], amalgamations: [{},..]}}
    end
    # rubocop: enable Metrics/AbcSize

    # Expect a string (bang since this is will modify the db)
    def answer_review_meaning!(answer)
      is_correct = get_review[:meanings].any? { |reading_hash| reading_hash['meaning'].downcase == answer.downcase }

      if is_correct
        @review.pass_meaning!
      else
        @review.fail_meaning!
      end

      is_correct
      # Return bool, whether the asnwer was correct
    end

    # Expect a string (bang since this is will modify the db)
    def answer_review_reading!(answer)
      is_correct = get_review[:readings].any? { |reading_hash| reading_hash['reading'] == answer }

      if is_correct
        @review.pass_reading!
      else
        @review.fail_reading!
      end

      is_correct
      # Return bool, whether the asnwer was correct
    end

    def progress_statuss_reviews
      available_reviews = @common_query.count_available_reviews
      return 0 if available_reviews.zero?

      @common_query.count_pending_review_reports / available_reviews.to_f
      # Return float, 0.0 - 1.0 representing % of all available reviews completed and unreported
    end

    # ==============
    # Lesson section
    # ==============

    # TODO

    # ==============
    #  Misc section
    # ==============

    def fetch!
      updated_after = @common_query.get_last_sync_time

      subjects = DataNormalizer.subjects(@api.fetch_subjects(updated_after))
      assignments = DataNormalizer.assignments(@api.fetch_assignments(updated_after))
      Persister.persist(@db, DataNormalizer.unite!(subjects, assignments))

      Persister.update_user_data(@db, @api.fetch_user_data(updated_after))

      @db.execute('INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)', ['updated_after', Time.now.utc.iso8601])
      @review.update_review_table!
    end

    def submit!
      reviews = @common_query.get_all_passed_reviews_as_hash
      reviews.each do |review|
        payload = PayloadGenerator.make(review)
        @api.submit_review(payload)
      end
    end

    private

    def fetch_api_key
      Database.new(check_bypass: true).get_first_row('SELECT value FROM meta WHERE key = ?', ['api_key'])&.first
    rescue SQLite3::SQLException
      nil
    end
  end
end
