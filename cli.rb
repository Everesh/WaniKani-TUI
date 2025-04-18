# frozen_string_literal: true

require_relative 'lib/wanikani'
require_relative 'lib/review'
require 'logger'
require 'romkan'

COMMAND_EXIT = ':q'
COMMAND_REPORT = ':w'
COMMAND_SYNC = ':u'

Wanikani::LOGGER.level = Logger::UNKNOWN

puts "\n▖  ▖    ▘▖▖    ▘  ▄▖▜ ▘"
puts   '▌▞▖▌▀▌▛▌▌▙▘▀▌▛▌▌▄▖▌ ▐ ▌'
puts   "▛ ▝▌█▌▌▌▌▌▌█▌▌▌▌  ▙▖▐▖▌ v0.0.0\n"
puts ''
puts "==| Exit: #{COMMAND_EXIT}"
puts "==| Report: #{COMMAND_REPORT}"
puts "==| Force Sync: #{COMMAND_SYNC}"

reviews = Review.new(buffer_size: 5)

while reviews.next
  next_step = if !reviews.meaning_passed? && !reviews.reading_passed?
                rand(2)
              else
                reviews.meaning_passed? ? 1 : 0
              end # reading : 1, meaning : 0
  puts ''
  puts "==| Left: #{reviews.left} | Completed: #{reviews.completed}"
  if next_step == 1
    puts "==| #{reviews.next_type} | Reading:"
    puts "==#   #{reviews.next_word}"
    print '==? '
    answer = gets.chomp
    case answer
    when COMMAND_EXIT
      break
    when COMMAND_REPORT
      reviews.report_all
      next
    when COMMAND_SYNC
      reviews.sync
      next
    else
      puts "==| Expected: \"#{reviews.next.dig('data', 'readings').first['reading']}\""
      puts "==| Parsed as: \"#{answer.to_kana}\""
      if reviews.answer_reading(answer)
        puts '==| CORRECT + + + + + + + + + + + + + + +'
      else
        puts '==| INCORRECT - - - - - - - - - - - - - -'
      end
    end
  else
    puts "==| #{reviews.next_type} | Meaning:"
    puts "==#   #{reviews.next_word}"
    print '==? '
    answer = gets.chomp
    case answer
    when COMMAND_EXIT
      break
    when COMMAND_REPORT
      reviews.report_all
      next
    when COMMAND_SYNC
      reviews.sync
      next
    else
      break if answer == COMMAND_EXIT

      puts "==| Expected: \"#{reviews.next.dig('data', 'meanings').first['meaning']}\""
      if reviews.answer_meaning(answer)
        puts '==| CORRECT + + + + + + + + + + + + + + +'
      else
        puts '==| INCORRECT - - - - - - - - - - - - - -'
      end
    end
  end
end
