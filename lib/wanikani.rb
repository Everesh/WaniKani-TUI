# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'dotenv/load'
require 'fileutils'
require 'logger'

# Provides methods to fetch and cache data from the WaniKani API.
module Wanikani
  class RateLimitError < StandardError; end
  API_KEY = ENV['WANIKANI_API_KEY']
  raise 'WANIKANI_API_KEY is not set!' if API_KEY.nil? || API_KEY.strip.empty?

  CACHE_PATH = File.join(__dir__, '../cache')
  ASSIGNMENTS_CACHE_FILE = File.join(CACHE_PATH, 'assignments.json')
  SUBJECTS_CACHE_FILE = File.join(CACHE_PATH, 'subjects.json')

  LOGGER = Logger.new($stdout) # Temporary STDOUT dump
  LOGGER.level = Logger::INFO

  def self.fetch_assignments(force: false)
    FileUtils.mkdir_p(CACHE_PATH)

    if File.exist?(ASSIGNMENTS_CACHE_FILE) && !force
      LOGGER.info('Using cached assignments.')
      return
    end

    LOGGER.info('Fetching assignments from WaniKani...')
    all_assignments = request_all_data('https://api.wanikani.com/v2/assignments')

    File.write(ASSIGNMENTS_CACHE_FILE, JSON.pretty_generate(all_assignments))
    LOGGER.info("Assignments cached to #{ASSIGNMENTS_CACHE_FILE}")
  end

  def self.fetch_all_subjects(force: false)
    FileUtils.mkdir_p(CACHE_PATH)

    if File.exist?(SUBJECTS_CACHE_FILE) && !force
      LOGGER.info('Using cached subjects.')
      return
    end

    LOGGER.info('Fetching subjects from WaniKani...')
    all_subjects = request_all_data('https://api.wanikani.com/v2/subjects')

    File.write(SUBJECTS_CACHE_FILE, JSON.pretty_generate(all_subjects))
    LOGGER.info("Subjects cached to #{SUBJECTS_CACHE_FILE}")
  end

  def self.report_review(payload)
    url = 'https://api.wanikani.com/v2/reviews/'
    uri = URI(url)

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      req = Net::HTTP::Post.new(uri)
      req['Authorization'] = "Bearer #{API_KEY}"
      req['Content-Type'] = 'application/json; charset=utf-8'
      req.body = JSON.generate(payload)
      http.request(req)
    end

    unless response.is_a?(Net::HTTPSuccess)
      LOGGER.error("POST failed with code #{response.code}")
      case response.code.to_i
      when 429
        raise RateLimitError, "Rate limited: #{response.body}"
      else
        raise StandardError, "Error during POST request: #{response.code}"
      end
    end

    LOGGER.info("POST successful: #{response.code}")
  end

  def self.request_all_data(url)
    all_pages = []
    page = 1

    while url
      LOGGER.debug("Requesting page #{page} - #{url}")
      begin
        data = request(url)
      rescue RateLimitError => e
        LOGGER.warn("Rate limited: #{e.message}, sleeping 60 sec...")
        sleep(60)
        retry
      rescue StandardError => e
        LOGGER.error("Unexpected error: #{e}")
        return
      end
      all_pages.concat(data['data'])
      url = data.dig('pages', 'next_url')
      page += 1
    end

    LOGGER.info("Fetched #{all_pages.size} items in total.")
    all_pages
  end

  def self.request(url)
    uri = URI(url)

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      req = Net::HTTP::Get.new(uri)
      req['Authorization'] = "Bearer #{API_KEY}"
      http.request(req)
    end

    case response.code.to_i
    when 200..299
      LOGGER.info("Successful response from #{url}")
    when 429
      LOGGER.warn("Rate limited: #{response.code}")
      raise RateLimitError, "Rate limited: #{response.body}"
    else
      LOGGER.error("Request failed with code #{response.code}")
      raise StandardError, "Error during GET request: #{response.code}"
    end

    JSON.parse(response.body)
  end

  private_class_method :request_all_data, :request
end
