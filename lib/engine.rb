# frozen_string_literal: true

# rubocop: disable Metrics/ClassLength

require 'time'
require 'amatch'

require_relative 'db/database'
require_relative 'wanikani_api'
require_relative 'util/data_normalizer'
require_relative 'db/persister'
require_relative 'review'
require_relative 'lesson'
require_relative 'util/data_dir'
require_relative 'error/missing_api_key_error'
require_relative 'db/common_query'
require_relative 'util/payload_generator'

module WaniKaniTUI
  # Manages the core functionality of the application.
  class Engine
    DEFAULT_TYPO_STRICTNESS = 0.8

    attr_reader :common_query

    # rubocop: disable Metrics
    def initialize(force_db_regen: false, api_key: nil, status_line: nil)
      if force_db_regen && api_key.nil?
        api_key = fetch_api_key # Attempts to carry over the previous API key to the new DB
        raise MissingApiKeyError, 'Could not fetch existing API key, new one is required' if api_key.nil?
      end

      @status_line = status_line

      @status_line&.status('Initializing the database...')
      @db = Database.new(force_db_regen: force_db_regen)

      @status_line&.status('Initializing the api module...')
      @api = WaniKaniAPI.new(@db, api_key: api_key, status_line: @status_line)

      @status_line&.status('Initializing the query module...')
      @common_query = CommonQuery.new(@db)

      @status_line&.status('Loading user preferences...')
      @preferences = DataDir.preferences
      custom_review_buffer_size = @preferences['review_buffer_size']
      custom_lesson_buffer_size = @preferences['lesson_buffer_size']

      @status_line&.status('Initializing the review module...')
      @review = custom_review_buffer_size ? Review.new(@db, buffer_size: custom_review_buffer_size) : Review.new(@db)

      @status_line&.status('Initializing the lesson module...')
      @lesson = custom_lesson_buffer_size ? Lesson.new(@db, buffer_size: custom_lesson_buffer_size) : Lesson.new(@db)

      @status_line&.status('Fetching from remote...')
      fetch!
    ensure
      @status_line.clear
    end
    # rubocop: enable Metrics

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
      is_correct = get_review[:meanings].any? do |meaning_hash|
        similarity = meaning_hash['meaning'].downcase.damerau_levenshtein_similar(answer.downcase)
        similarity >= (@preferences['typo_strictness'] || DEFAULT_TYPO_STRICTNESS) && meaning_hash['accepted'] == 1
      end

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
      is_correct = get_review[:readings].any? do |reading_hash|
        reading_hash['reading'] == answer && reading_hash['accepted'] == 1
      end

      if is_correct
        @review.pass_reading!
      else
        @review.fail_reading!
      end

      is_correct
      # Return bool, whether the asnwer was correct
    end

    def progress_statuss_reviews
      total_reviews = @common_query.count_total_reviews
      return 0 if total_reviews.zero?

      @common_query.count_pending_review_reports / total_reviews.to_f
      # Return float, 0.0 - 1.0 representing % of all available reviews completed and unreported
    end

    # ==============
    # Lesson section
    # ==============

    # rubocop: disable Naming/AccessorMethodName
    def get_lesson
      lesson = @lesson.peek_as_hash
      assignment = @common_query.get_assignment_by_assignment_id_as_hash(lesson[:assignment_id])
      subject = @common_query.get_subject_by_id_as_hash(lesson[:subject_id])
      components = @common_query.get_components_by_id_as_hash(lesson[:subject_id])
      amalgamations = @common_query.get_amalgamations_by_id_as_hash(lesson[:subject_id])
      meanings = @common_query.get_meanings_by_id_as_hash(lesson[:subject_id])
      readings = @common_query.get_readings_by_id_as_hash(lesson[:subject_id])
      { lesson: lesson, assignment: assignment, subject: subject, readings: readings, meanings: meanings,
        components: components, amalgamations: amalgamations }
      # Return structured hash with all the relevant data from the front of the buffer
      # e.g {review: {}, assignment: {}, subject: {}, readings: [{},..], meanings: [{},..],
      #      components: [{},..], amalgamations: [{},..]}}
    end
    # rubocop: enable Naming/AccessorMethodName

    def lesson_seen!
      @lesson.seen!
    end

    def lesson_unsee!
      @lesson.unsee!
    end

    def lesson_buffer_size
      @lesson.buffer_size
    end

    def answer_lesson_meaning!(answer)
      is_correct = get_lesson[:meanings].any? do |meaning_hash|
        similarity = meaning_hash['meaning'].downcase.damerau_levenshtein_similar(answer.downcase)
        similarity >= (@preferences['typo_strictness'] || DEFAULT_TYPO_STRICTNESS) && meaning_hash['accepted'] == 1
      end

      if is_correct
        @lesson.pass_meaning!
      else
        @lesson.rotate!
      end

      is_correct
    end

    def answer_lesson_reading!(answer)
      is_correct = get_lesson[:readings].any? do |reading_hash|
        reading_hash['reading'] == answer && reading_hash['accepted'] == 1
      end

      if is_correct
        @lesson.pass_reading!
      else
        @lesson.rotate!
      end

      is_correct
    end

    # ==============
    #  Misc section
    # ==============

    # rubocop: disable Metrics
    def fetch!
      @status_line&.status('Getting last sync time...')
      updated_after = @common_query.get_last_sync_time

      @status_line&.status('Fetching subjects...')
      subjects = DataNormalizer.subjects(@api.fetch_subjects(updated_after))

      @status_line&.status('Fetching assignments...')
      assignments = DataNormalizer.assignments(@api.fetch_assignments(updated_after))

      @status_line&.status('Persisting data...')
      Persister.persist(@db, DataNormalizer.unite!(subjects, assignments))

      @status_line&.status('Updating metadata...')
      Persister.update_user_data(@db, @api.fetch_user_data(updated_after))
      @db.execute('INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)', ['updated_after', Time.now.utc.iso8601])

      @status_line&.status('Updating review table...')
      @review.update_review_table!
      @status_line&.status('Updating review buffer...')
      @review.update_buffer!
      @status_line&.status('Updating lesson buffer...')
      @lesson.update_buffer!
    rescue Socket::ResolutionError
      @status_line.state('No internet connection. Could not fetch!')
      sleep(1)
    ensure
      @status_line.clear
    end

    def submit!
      @status_line&.status('Fetching finished reviews...')
      reviews = @common_query.get_all_passed_reviews_with_chars_as_hash
      reviews.each do |review|
        @status_line&.status("Preparing payload for '#{review['characters'] || review['slug']}'...")
        payload = PayloadGenerator.review(review)
        @status_line&.status("Reporting '#{review['characters'] || review['slug']}'...")
        @api.submit_review(payload)
      end

      @status_line&.status('Fetching finished lessons...')
      lessons = @common_query.get_all_passed_lessons_with_chars_as_hash
      lessons.each do |lesson|
        @status_line&.status("Preparing payload for '#{lesson['characters'] || lesson['slug']}'...")
        payload = PayloadGenerator.lesson(lesson)
        @status_line&.status("Reporting '#{lesson['characters'] || lesson['slug']}'...")
        @api.submit_lesson(payload, lesson['assignment_id'])
      end
    rescue Socket::ResolutionError
      @status_line.state('No internet connection. Could not submit!')
      sleep(1)
    ensure
      @status_line.clear
    end
    # rubocop: enable Metrics

    private

    def fetch_api_key
      Database.new(check_bypass: true).get_first_row('SELECT value FROM meta WHERE key = ?', ['api_key'])&.first
    rescue SQLite3::SQLException
      nil
    end
  end
end

# rubocop: enable Metrics/ClassLength
