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
    def initialize(force_db_regen: false, api_key: nil, status_line: nil)
      if force_db_regen && api_key.nil?
        api_key = fetch_api_key # Attempts to carry over the previous API key to the new DB
        raise MissingApiKeyError, 'Could not fetch existing API key, new one is required' if api_key.nil?
      end

      @status_line = status_line
      @status_line.status('Initializing the database...') unless @status_line.nil?
      @db = Database.new(force_db_regen: force_db_regen)
      @status_line.status('Initializing the api module...') unless @status_line.nil?
      @api = WaniKaniAPI.new(@db, api_key: api_key, status_line: @status_line)
      @status_line.status('Initializing the query module...') unless @status_line.nil?
      @common_query = CommonQuery.new(@db)
      @status_line.status('Loading user preferences...') unless @status_line.nil?
      @preferences = DataDir.preferences
      custom_buffer_size = @preferences['buffer_size']
      @status_line.status('Initializing the review module...') unless @status_line.nil?
      @review = custom_buffer_size ? Review.new(@db, buffer_size: custom_buffer_size) : Review.new(@db)
      @status_line.status('Fetching from remote...') unless @status_line.nil?
      fetch!
    ensure
      @status_line.clear
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
      @status_line.status('Getting last sync time...') unless @status_line.nil?
      updated_after = @common_query.get_last_sync_time

      @status_line.status('Fetching subjects...') unless @status_line.nil?
      subjects = DataNormalizer.subjects(@api.fetch_subjects(updated_after))
      @status_line.status('Fetching assignments...') unless @status_line.nil?
      assignments = DataNormalizer.assignments(@api.fetch_assignments(updated_after))
      @status_line.status('Persisting data...') unless @status_line.nil?
      Persister.persist(@db, DataNormalizer.unite!(subjects, assignments))

      @status_line.status('Updating metadata...') unless @status_line.nil?
      Persister.update_user_data(@db, @api.fetch_user_data(updated_after))

      @db.execute('INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)', ['updated_after', Time.now.utc.iso8601])
      @status_line.status('Updating review table...') unless @status_line.nil?
      @review.update_review_table!
    ensure
      @status_line.clear
    end

    def submit!
      @status_line.status('Fetching finished reviews...') unless @status_line.nil?
      reviews = @common_query.get_all_passed_reviews_with_chars_as_hash
      reviews.each do |review|
        unless @status_line.nil?
          @status_line.status("Preparing payload for '#{review['characters'] || review['slug']}'...")
        end
        payload = PayloadGenerator.make(review)
        @status_line.status("Reporting '#{review['characters'] || review['slug']}'...") unless @status_line.nil?
        @api.submit_review(payload)
      end
    ensure
      @status_line.clear
    end

    private

    def fetch_api_key
      Database.new(check_bypass: true).get_first_row('SELECT value FROM meta WHERE key = ?', ['api_key'])&.first
    rescue SQLite3::SQLException
      nil
    end
  end
end
