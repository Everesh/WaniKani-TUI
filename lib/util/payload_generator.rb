# frozen_string_literal: true

module WaniKaniTUI
  # Takes hashes from the Review table and turns them into hashes ready for submission
  class PayloadGenerator
    def self.make(review)
      {
        'review' => {
          'assignment_id' => review['assignment_id'],
          'incorrect_meaning_answers' => review['incorrect_meaning_answers'] || 0,
          'incorrect_reading_answers' => review['incorrect_reading_answers'] || 0,
          'created_at' => review['created_at']
        }
      }
    end
  end
end
