# frozen_string_literal: true

require_relative 'database'

module WaniKaniTUI
  # Takes pre-processed objects and efficiently inserts them into the DB
  class Persister
    def self.persist(db, hash)
      raise ArgumentError, 'Expected a WaniKaniTUI::Database instance' unless db.is_a?(WaniKaniTUI::Database)

      db.transaction do
        persist_subjects(db, hash[:subjects])
        persist_meanings(db, hash[:meanings])
        persist_readings(db, hash[:readings])
        persist_components(db, hash[:components])
        persist_assignments(db, hash[:assignments])
      end
    end

    # privatized methods of the static class
    class << self
      private

      # rubocop: disable Metrics/MethodLength
      def persist_subjects(db, subjects)
        subjects.each do |subject|
          db.execute(
            "INSERT INTO subject
             (id, characters, level, object, slug, url, mnemonic_reading, mnemonic_meaning)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)
             ON CONFLICT(id) DO UPDATE SET
              characters = excluded.characters,
              level = excluded.level,
              object = excluded.object,
              slug = excluded.slug,
              url = excluded.url,
              mnemonic_reading = excluded.mnemonic_reading,
              mnemonic_meaning = excluded.mnemonic_meaning",
            subject
          )
        end
      end
      # rubocop: enable Metrics/MethodLength

      def persist_meanings(db, meanings)
        meanings.each do |meaning|
          db.execute('INSERT OR IGNORE INTO meaning (meaning) VALUES (?)', meaning[1])
          db.execute(
            "INSERT OR REPLACE INTO subject_meaning
             (id, meaning, \"primary\", accepted)
             VALUES (?, ?, ?, ?)",
            meaning
          )
        end
      end

      def persist_readings(db, readings)
        readings.each do |reading|
          db.execute('INSERT OR IGNORE INTO reading (reading) VALUES (?)', reading[1])
          db.execute(
            "INSERT OR REPLACE INTO subject_reading
             (id, reading, \"primary\", accepted, type)
             VALUES (?, ?, ?, ?, ?)",
            reading
          )
        end
      end

      def persist_components(db, components)
        components.each do |component|
          db.execute(
            "INSERT OR REPLACE INTO components
             (id_component, id_product)
             VALUES (?, ?)",
            component
          )
        end
      end

      def persist_assignments(db, assignments)
        assignments.each do |assignment|
          db.execute(
            "INSERT OR REPLACE INTO assignment
             (assignment_id, subject_id, srs, hidden, available_at, started_at)
             VALUES (?, ?, ?, ?, ?, ?)",
            assignment
          )
        end
      end
    end
  end
end
