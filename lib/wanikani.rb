require 'net/http'
require 'json'
require 'uri'
require 'dotenv/load'

module Wanikani
  API_TOKEN = ENV['WANIKANI_API_KEY']
  raise 'WANIKANI_API_KEY is not set!' if API_TOKEN.nil? || API_TOKEN.strip.empty?

  CACHE_PATH = File.join(__dir__, '../cache')
  ASSIGNMENTS_CACHE_FILE = File.join(CACHE_PATH, 'assignments.json')
  SUBJECTS_CACHE_FILE = File.join(CACHE_PATH, 'subjects.json')

  def self.fetch_assignments(force: false)
    FileUtils.mkdir_p(CACHE_PATH)
    return if File.exist?(ASSIGNMENTS_CACHE_FILE) && !force

    all_assignments = []
    url = 'https://api.wanikani.com/v2/assignments'

    while url
      uri = URI(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        req = Net::HTTP::Get.new(uri)
        req['Authorization'] = "Bearer #{API_TOKEN}"
        http.request(req)
      end

      case response
      when Net::HTTPSuccess
        data = JSON.parse(response.body)
        all_assignments += data['data']
        url = data['pages']['next_url']
        break unless url
      else
        puts "Error fetching assignments: #{response.code}"
        break
      end
    end

    File.write(ASSIGNMENTS_CACHE_FILE, JSON.pretty_generate(all_assignments))
  end

  def self.fetch_all_subjects(force: false)
    FileUtils.mkdir_p(CACHE_PATH)
    return if File.exist?(SUBJECTS_CACHE_FILE) && !force

    all_subjects = []
    url = 'https://api.wanikani.com/v2/subjects'

    while url
      uri = URI(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        req = Net::HTTP::Get.new(uri)
        req['Authorization'] = "Bearer #{API_TOKEN}"
        http.request(req)
      end

      case response
      when Net::HTTPSuccess
        data = JSON.parse(response.body)
        all_subjects += data['data']
        url = data['pages']['next_url']
        break unless url
      else
        puts "Error fetching subjects: #{response.code}"
        break
      end
    end

    File.write(SUBJECTS_CACHE_FILE, JSON.pretty_generate(all_subjects))
  end
end
