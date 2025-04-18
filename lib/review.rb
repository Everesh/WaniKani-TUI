# frozen_string_literal: true

require_relative 'wanikani'
require 'json'
require 'time'
require 'amatch'
require 'romkan'

# Manages pending review queue and its progress
class Review
  def initialize(buffer_size: 5)
    @done = []
    @queue = []
    @buffer = []
    @buffer_size = buffer_size
    regen_queue
    update_buffer
  end

  def left
    @queue.size + @buffer.size
  end

  def next
    @buffer.first
  end

  def next_word
    @buffer.first.dig('data', 'characters')
  end

  def next_type
    @buffer.first['object']
  end

  def meaning_passed?
    @buffer.first['meaning_passed']
  end

  def answer_meaning(answer)
    raise 'Meaning already answered' if @buffer.first['meaning_passed']

    answer = Amatch::JaroWinkler.new(answer.downcase)
    meanings = @buffer.first.dig('data', 'meanings').map { |hash| hash['meaning'] }
    meanings.concat(@buffer.first.dig('data', 'auxiliary_meanings').map { |hash| hash['meaning'] })
    if meanings.any? { |meaning| answer.match(meaning.downcase) >= 0.9 }
      @buffer.first['meaning_passed'] = true
      if @buffer.first['reading_passed'] || next_type == 'radical'
        @buffer.first['time_passed'] = Time.now.utc.iso8601(6)
        @done << @buffer.shift
        update_buffer
      else
        @buffer << @buffer.shift
      end
      true
    else
      @buffer.first['invalid_meanings'] += 1
      @buffer << @buffer.shift
      false
    end
  end

  def reading_passed?
    @buffer.first['reading_passed']
  end

  def answer_reading(answer)
    raise 'Reading already answered' if @buffer.first['reading_passed']

    answer = answer.to_kana
    readings = @buffer.first.dig('data', 'readings').map { |hash| hash['reading'] }
    if readings.any? { |reading| reading == answer }
      @buffer.first['reading_passed'] = true
      if @buffer.first['meaning_passed']
        @buffer.first['time_passed'] = Time.now.utc.iso8601(6)
        @done << @buffer.shift
        update_buffer
      else
        @buffer << @buffer.shift
      end
      true
    else
      @buffer.first['invalid_readings'] += 1
      @buffer << @buffer.shift
      false
    end
  end

  def pass_next
    @buffer.first['time_passed'] = Time.now.utc.iso8601(6)
    @done << @buffer.shift
    update_buffer
  end

  def completed
    @done.size
  end

  def last
    @buffer.last
  end

  def last_word
    @buffer.last.dig('data', 'characters')
  end

  def last_type
    @buffer.last['object']
  end

  def report_all
    return if @done.empty?

    Wanikani::LOGGER.info('Begining review reporting...')
    @done.each do |review|
      payload = make_payload(review)
      Wanikani.report_review(payload)
    rescue Wanikani::RateLimitError => e
      Wanikani::LOGGER.warn("#{e.message}, sleeping 60 sec...")
      sleep(60)
      retry
    rescue StandardError => e
      Wanikani::LOGGER.error("Unexpected error: #{e}")
      break
    end

    sync
  end

  def sync
    Wanikani::LOGGER.info('Updating assignments...')
    Wanikani.fetch_assignments(force: true)
    Wanikani::LOGGER.info('Regenerating queue...')
    @queue = []
    regen_queue
    Wanikani::LOGGER.info('Regenerating buffer...')
    @buffer = []
    update_buffer
    Wanikani::LOGGER.info('Clearing pending report cache...')
    @done = []
  end

  private

  def regen_queue
    populate_queue_by_ids
    map_queue_ids_to_subjects
    shuffle_queue
  end

  def populate_queue_by_ids
    begin
      assignments = get_cached(Wanikani::ASSIGNMENTS_CACHE_FILE)
    rescue StandardError => e
      Wanikani::LOGGER.warn("Failed to load assignments from cache: #{e.message}")
      Wanikani.fetch_assignments
      retry
    end

    Wanikani::LOGGER.info('Filtering due reviews...')
    now = Time.now

    @queue = assignments.select do |assignment|
      available_at = assignment.dig('data', 'available_at')
      started = assignment.dig('data', 'started_at')
      available_at && Time.parse(available_at) < now && started
    end

    @queue.map! do |assignment|
      [assignment['id'], assignment.dig('data', 'subject_id')]
    end
  end

  def map_queue_ids_to_subjects
    begin
      subjects = get_cached(Wanikani::SUBJECTS_CACHE_FILE)
    rescue StandardError => e
      Wanikani::LOGGER.warn("Failed to load subjects from cache: #{e.message}")
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

  def shuffle_queue
    @queue.shuffle!
  end

  def get_cached(path)
    raise "#{path} does not exist" unless File.exist?(path)

    Wanikani::LOGGER.info('Parsing data from cache...')
    JSON.parse(File.read(path))
  end

  def update_buffer
    Wanikani::LOGGER.info('Populating buffer...')
    while @buffer.length < @buffer_size && !@queue.empty?
      item = @queue.shift
      item['reading_passed'] = false
      item['invalid_readings'] = 0
      item['meaning_passed'] = false
      item['invalid_meanings'] = 0
      @buffer << item
    end
  end

  def make_payload(review)
    {
      'review' => {
        'assignment_id' => review['assignment_id'],
        'incorrect_meaning_answers' => review['invalid_meanings'],
        'incorrect_reading_answers' => review['invalid_readings'],
        'created_at' => review['time_passed']
      }
    }
  end
end
