# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'dotenv/load'

# Provides methods to fetch and cache data from the WaniKani API.
module Wanikani
  API_KEY = ENV['WANIKANI_API_KEY']
  raise 'WANIKANI_API_KEY is not set!' if API_KEY.nil? || API_KEY.strip.empty?

  CACHE_PATH = File.join(__dir__, '../cache')
  ASSIGNMENTS_CACHE_FILE = File.join(CACHE_PATH, 'assignments.json')
  SUBJECTS_CACHE_FILE = File.join(CACHE_PATH, 'subjects.json')

  def self.fetch_assignments(force: false)
    FileUtils.mkdir_p(CACHE_PATH)
    return if File.exist?(ASSIGNMENTS_CACHE_FILE) && !force

    all_assignments = request_all_data('https://api.wanikani.com/v2/assignments')

    File.write(ASSIGNMENTS_CACHE_FILE, JSON.pretty_generate(all_assignments))
  end

  def self.fetch_all_subjects(force: false)
    FileUtils.mkdir_p(CACHE_PATH)
    return if File.exist?(SUBJECTS_CACHE_FILE) && !force

    all_subjects = request_all_data('https://api.wanikani.com/v2/subjects')

    File.write(SUBJECTS_CACHE_FILE, JSON.pretty_generate(all_subjects))
  end

  def self.request_all_data(url)
    all_pages = []

    while url
      data = request(url)
      all_pages.concat(data['data'])
      url = data.dig('pages', 'next_url')
    end

    all_pages
  end

  def self.request(url)
    uri = URI(url)

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      req = Net::HTTP::Get.new(uri)
      req['Authorization'] = "Bearer #{API_KEY}"
      http.request(req)
    end

    raise "Error during GET request: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  private_class_method :request_all_data, :request
end
