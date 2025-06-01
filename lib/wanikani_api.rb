# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

require_relative 'db/database'
require_relative 'rate_limit_error'

module WaniKaniTUI
  # Handles the interaction between the app and the WaniKani API
  class WaniKaniAPI
    def initialize(db, api_key: nil)
      @db = db
      if api_key
        @api_key = api_key
        @db.execute('INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)', ['api_key', api_key])
      else
        @api_key = @db.get_first_row("SELECT value FROM meta WHERE key='api_key'")
        raise 'API key not set!' if @api_key.nil?

        @api_key = @api_key.first
      end
    end

    def fetch_subjects(updated_after)
      url = 'https://api.wanikani.com/v2/subjects'
      data = request_bulk(url, updated_after)
      save_subjects(data)
    end

    def fetch_assignments(updated_after)
      url = 'https://api.wanikani.com/v2/assignments'
      data = request_bulk(url, updated_after)
      save_assignments(data)
    end

    def dummy_subjects
      save_subjects(JSON.parse(File.read(File.join(__dir__, '../tmp/subjects.json'))))
    end

    def dummy_assignments
      save_assignments(JSON.parse(File.read(File.join(__dir__, '../tmp/assignments.json'))))
    end

    private

    def request_bulk(url, updated_after)
      all_pages = []

      while url
        next_page = attempt_request(url, updated_after)
        all_pages.concat(next_page['data'])
        url = next_page.dig('pages', 'next_url')
      end
      all_pages
    end

    def attempt_request(url, updated_after)
      response = request(URI(url), updated_after)
      parse_response(response)
    rescue RateLimitError
      sleep(60)
      retry
    end

    def request(uri, updated_after)
      if updated_after
        query = URI.decode_www_form(uri.query || '') << ['updated_after', updated_after]
        uri.query = URI.encode_www_form(query)
      end

      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        req = Net::HTTP::Get.new(uri)
        req['Authorization'] = "Bearer #{@api_key}"
        http.request(req)
      end
    end

    def parse_response(response)
      case response.code.to_i
      when 429
        raise RateLimitError, "Rate limited: #{response.body}"
      when 400..499
        raise StandardError, "Error during GET request: #{response.code}"
      end

      JSON.parse(response.body)
    end

    def save_subjects(data)
      @db.execute('PRAGMA foreign_keys = OFF;')
      data.each do |h|
        @db.execute('INSERT OR REPLACE INTO subject (id, characters, level, object, slug, url) VALUES (?,?,?,?,?,?)',
                    [h['id'], h['data']['characters'], h['data']['level'], h['object'], h['data']['slug'], h['data']['document_url']])
        save_meanings(h)
        save_readings(h)
        save_component(h) if h['object'] == 'kanji'
      end
      @db.execute('PRAGMA foreign_keys = ON;')
    end

    def save_component(kanji)
      kanji['data']['component_subject_ids'].each do |r|
        @db.execute('INSERT OR REPLACE INTO components (id_component, id_product) VALUES (?, ?)', [r, kanji['id']])
      end
      kanji['data']['amalgamation_subject_ids'].each do |v|
        @db.execute('INSERT OR REPLACE INTO components (id_component, id_product) VALUES (?, ?)', [kanji['id'], v])
      end
    end

    def save_meanings(subject)
      @db.execute('UPDATE subject SET mnemonic_meaning = ? WHERE id = ?',
                  [subject['data']['meaning_mnemonic'], subject['id']])

      primary_meanings = subject['data']['meanings']
      aux_meanings = subject['data']['auxiliary_meanings'] || []

      (primary_meanings + aux_meanings).each do |m|
        @db.execute('INSERT OR REPLACE INTO meaning (meaning) VALUES (?)', [m['meaning']])
        primary = m['primary'] ? 1 : 0
        accepted = m['accepted_answer'] ? 1 : 0
        @db.execute('INSERT OR REPLACE INTO subject_meaning (id, meaning, "primary", accepted) VALUES (?,?,?,?)',
                    [subject['id'], m['meaning'], primary, accepted])
      end
    end

    def save_readings(subject)
      return unless subject['data']['readings']
      @db.execute('UPDATE subject SET mnemonic_reading = ? WHERE id = ?',
                  [subject['data']['reading_mnemonic'], subject['id']])

      subject['data']['readings'].each do |r|
        @db.execute('INSERT OR REPLACE INTO reading (reading) VALUES (?)', [r['reading']])
        primary = r['primary'] ? 1 : 0
        accepted = r['accepted_answer'] ? 1 : 0
        @db.execute('INSERT OR REPLACE INTO subject_reading (id, reading, "primary", accepted, type) VALUES (?,?,?,?,?)',
                    [subject['id'], r['reading'], primary, accepted, r['type']])
      end
    end

    def save_assignments(data)
      data.each do |a|
        hidden = a['data']['hidden'] ? 1 : 0
        @db.execute('INSERT OR REPLACE INTO assignment (assignment_id, subject_id, srs, hidden, available_at, started_at) VALUES (?,?,?,?,?,?)',
                    [a['id'], a['data']['subject_id'], a['data']['srs_stage'], hidden, a['data']['available_at'], a['data']['started_at']])
      end
    end
  end
end
