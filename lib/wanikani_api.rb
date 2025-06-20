# frozen_string_literal: true

# rubocop: disable Metrics/ClassLength

require 'net/http'
require 'json'
require 'uri'

require_relative 'db/database'
require_relative 'error/rate_limit_error'
require_relative 'error/invalid_api_key_error'
require_relative 'error/missing_api_key_error'

module WaniKaniTUI
  # Handles the interaction between the app and the WaniKani API
  class WaniKaniAPI
    def initialize(db, api_key: nil, status_line: nil)
      @db = db
      @api_key = api_key || fetch_api_key
      @status_line = status_line
      raise MissingApiKeyError, 'API key not set!' unless @api_key

      store_api_key(@api_key) if api_key
    end

    def fetch_subjects(updated_after)
      url = 'https://api.wanikani.com/v2/subjects'
      bulk_get(url, updated_after)
    end

    def fetch_assignments(updated_after)
      url = 'https://api.wanikani.com/v2/assignments'
      bulk_get(url, updated_after)
    end

    def fetch_user_data(updated_after)
      url = 'https://api.wanikani.com/v2/user'
      attempt_get(url, updated_after)
    end

    def submit_review(review)
      url = 'https://api.wanikani.com/v2/reviews/'
      attempt_post(url, review)
    end

    def submit_lesson(lesson_payload, lesson_id)
      url = "https://api.wanikani.com/v2/assignments/#{lesson_id}/start"
      attempt_put(url, lesson_payload)
    end

    private

    def fetch_api_key
      @db.get_first_row('SELECT value FROM meta WHERE key = ?', ['api_key'])&.first
    end

    def store_api_key(key)
      @db.execute('INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)', ['api_key', key])
    end

    def bulk_get(url, updated_after)
      all_pages = []

      while url
        next_page = attempt_get(url, updated_after)
        all_pages.concat(next_page['data'])
        url = next_page.dig('pages', 'next_url')
      end
      all_pages
    end

    def attempt_get(url, updated_after)
      response = get(URI(url), updated_after)
      parse_response(response)
    rescue RateLimitError
      count_down('Ratelimited, attempting again', 60)
      retry
    end

    def get(uri, updated_after)
      if updated_after
        query = URI.decode_www_form(uri.query || '') << ['updated_after', updated_after]
        uri.query = URI.encode_www_form(query)
      end

      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        req = Net::HTTP::Get.new(uri)
        req['Wanikani-Revision'] = '20170710'
        req['Authorization'] = "Bearer #{@api_key}"
        http.request(req)
      end
    end

    def parse_response(response)
      case response.code.to_i
      when 401
        raise InvalidApiKeyError, "Invalid api key: #{@api_key}"
      when 429
        raise RateLimitError, "Rate limited: #{response.body}"
      when 400..499
        raise StandardError, "Error during request: #{response.code}"
      end

      JSON.parse(response.body)
    end

    def attempt_post(url, review)
      response = post(URI(url), review)
      parse_response(response)
    rescue RateLimitError
      count_down('Ratelimited, attempting again', 60)
      retry
    end

    def post(uri, review)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        req = Net::HTTP::Post.new(uri)
        req['Content-Type'] = 'application/json; charset=utf-8'
        req['Wanikani-Revision'] = '20170710'
        req['Authorization'] = "Bearer #{@api_key}"
        req.body = review.to_json
        http.request(req)
      end
    end

    def attempt_put(url, review)
      response = put(URI(url), review)
      parse_response(response)
    rescue RateLimitError
      count_down('Ratelimited, attempting again', 60)
      retry
    end

    def put(uri, review)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        req = Net::HTTP::Put.new(uri)
        req['Content-Type'] = 'application/json; charset=utf-8'
        req['Wanikani-Revision'] = '20170710'
        req['Authorization'] = "Bearer #{@api_key}"
        req.body = review.to_json
        http.request(req)
      end
    end

    def count_down(message, time, counted: 0)
      return if counted >= time

      @status_line&.status("#{message} in #{time - counted} seconds...")
      sleep(1)
      count_down(message, time, counted: counted + 1)
    end
  end
end

# rubocop: enable Metrics/ClassLength
