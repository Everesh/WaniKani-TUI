# frozen_string_literal: true

module WaniKaniTUI
  # Takes parsed JSON objects and pre-processes them for purposes of injection into the DB
  class DataNormalizer
    # Output presented as
    ## {
    ### subjects: [[id, characters, level, object, slug, url, mnemonic_r, mnemonic_m], ...]
    ### meanings: [[id, meaning, primary, accepted], ...]
    ### readings: [[id, reading, primary, accepted, type], ...]
    ### components: [[id_component, id_product], ...]
    ## }
    def self.subjects(data)
      normalized = { subjects: [], meanings: [], readings: [], components: [] }

      data.each do |subject|
        normalized[:subjects] << extract_subject(subject)
        normalized[:meanings] += extract_meanings(subject)
        normalized[:readings] += extract_readings(subject)
        normalized[:components] += extract_components(subject)
      end

      normalized
    end

    # Output presented as
    ### [[assignment_id, subject_id, srs, hidden, available_at, started_at], ...]
    def self.assignments(data)
      normalized = []

      data.each do |a|
        # Boolean to int conversion due to sqlite3 boolean representation
        normalized << [a['id'], a['data']['subject_id'], a['data']['srs_stage'],
                       a['data']['hidden'] ? 1 : 0, a['data']['available_at'],
                       a['data']['started_at'], a['data']['unlocked_at']]
      end
      normalized
    end

    def self.unite!(hash, assignments)
      hash[:assignments] = assignments
      hash
    end

    # privatized methods of the static class
    class << self
      private

      def extract_meanings(subject)
        subject['data']['meanings'].map { |m| extract_meaning(subject, m) }
      end

      def extract_readings(subject)
        return [] unless %w[kanji vocabulary].include?(subject['object'])

        subject['data']['readings'].map { |r| extract_reading(subject, r) }
      end

      def extract_components(subject)
        return [] unless subject['object'] == 'kanji'

        subject['data']['component_subject_ids'].map { |radical| radical_kanji(radical, subject) } +
          subject['data']['amalgamation_subject_ids'].map { |vocab| kanji_vocab(subject, vocab) }
      end

      def extract_subject(subject)
        [subject['id'], subject['data']['characters'], subject['data']['level'],
         subject['object'], subject['data']['slug'], subject['data']['document_url'],
         subject['data']['reading_mnemonic'], subject['data']['meaning_mnemonic'],
         subject['data']['hidden_at']]
      end

      # Boolean to int conversion due to sqlite3 boolean representation
      def extract_meaning(subject, meaning)
        [subject['id'], meaning['meaning'], meaning['primary'] ? 1 : 0,
         meaning['accepted_answer'] ? 1 : 0]
      end

      # Boolean to int conversion due to sqlite3 boolean representation
      def extract_reading(subject, reading)
        [subject['id'], reading['reading'], reading['primary'] ? 1 : 0,
         reading['accepted_answer'] ? 1 : 0, reading['type']]
      end

      def radical_kanji(radical, kanji)
        [radical, kanji['id']]
      end

      def kanji_vocab(kanji, vocab)
        [kanji['id'], vocab]
      end
    end
  end
end
