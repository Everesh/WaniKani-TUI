# frozen_string_literal: true

require_relative 'wanikani'
require 'json'
require 'time'

# Manages pending review queue and its progress
class Review
  def initialize
    @done = []
    @queue = []
    populate_queue_by_ids
    map_queue_ids_to_subjects
  end

  def left
    @queue.size
  end

  def next
    @queue.first
  end

  def completed
    @done.size
  end

  def done(incorrect_reading, incorrect_meaning)
    if !incorrect_reading.is_a?(Integer) || !incorrect_meaning.is_a?(Integer) ||
       incorrect_reading.negative? || incorrect_meaning.negative?
      Wanikani::LOGGET.error('Invalid count of incorrect reading/meaning attepts!')
      raise 'Invalid params for review completion!'
    end

    payload = {
      "review": {
        "assignment_id": @queue.shift['assignment_id'],
        "incorrect_meaning_answers": incorrect_meaning,
        "incorrect_reading_answers": incorrect_reading,
        "created_at": Time.now.utc.iso8601
      }
    }

    @done << payload
  end

  def last
    @done.last
  end

  def report_all
    return if @done.empty?

    Wanikani::LOGGER.info('Begining review reporting...')
    @done.each do |review|
      Wanikani.report_review(review)
    rescue Wanikani::RateLimitError => e
      Wanikani::LOGGER.warn("#{e.message}, sleeping 60 sec...")
      sleep(60)
      retry
    rescue StandardError => e
      Wanikani::LOGGER.error("Unexpected error: #{e}")
      break
    end

    Wanikani::LOGGER.info('Updating assignments...')
    Wanikani.fetch_assignments(force: true)
    Wanikani::LOGGER.info('Regenerating queue...')
    populate_queue_by_ids
    map_queue_ids_to_subjects
  end

  private

  def populate_queue_by_ids
    begin
      assignments = get_cached(Wanikani::ASSIGNMENTS_CACHE_FILE)
    rescue StandardError => e
      Wanikani::LOGGER.warn("Failed to load cached data from #{path}: #{e.message}")
      Wanikani.fetch_assignments
      retry
    end

    Wanikani::LOGGER.info('Filtering due reviews...')
    now = Time.now

    @queue = assignments.select do |assignment|
      available_at = assignment.dig('data', 'available_at')
      available_at && Time.parse(available_at) < now
    end

    @queue.map! do |assignment|
      [assignment['id'], assignment.dig('data', 'subject_id')]
    end
  end

  def map_queue_ids_to_subjects
    begin
      subjects = get_cached(Wanikani::SUBJECTS_CACHE_FILE)
    rescue StandardError => e
      Wanikani::LOGGER.warn("Failed to load cached data from #{path}: #{e.message}")
      Wanikani.fetch_all_subjects
      retry
    end

    Wanikani::LOGGER.info('Converting subjects to hash...')
    subjects_by_id = subjects.each_with_object({}) do |subject, hash|
      hash[subject['id']] = subject
    end

    Wanikani::LOGGER.info("Mapping id's to subject hashes")
    @queue.map! do |(assignment_id, subject_id)|
      subject = subjects_by_id[subject_id].dup
      subject['assignment_id'] = assignment_id
      subject
    end
  end

  def get_cached(path)
    raise "#{path} does not exist" unless File.exist?(path)

    Wanikani::LOGGER.info('Parsing data from cache...')
    JSON.parse(File.read(path))
  end
end
