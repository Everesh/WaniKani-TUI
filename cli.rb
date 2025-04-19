# frozen_string_literal: true

require_relative 'lib/wanikani'
require_relative 'lib/review'
require 'logger'
require 'romkan'
require 'colorize'

COMMAND_EXIT = ':q'
COMMAND_REPORT = ':w'
COMMAND_SYNC = ':u'

Wanikani::LOGGER.level = Logger::INFO

Wanikani::LOGGER.info('▖  ▖    ▘▖▖    ▘  ▄▖▜ ▘')
Wanikani::LOGGER.info('▌▞▖▌▀▌▛▌▌▙▘▀▌▛▌▌▄▖▌ ▐ ▌')
Wanikani::LOGGER.info('▛ ▝▌█▌▌▌▌▌▌█▌▌▌▌  ▙▖▐▖▌ v0.0.0')
Wanikani::LOGGER.info('')

reviews = Review.new(buffer_size: 5)

Wanikani::LOGGER.level = Logger::UNKNOWN

puts "\n==|" + ' Commands:'.bold
puts "==| Sync:   #{COMMAND_SYNC}" + '    | ' + 'Warning: Destroys pending reports'.colorize(:red)
puts "==| Report: #{COMMAND_REPORT}" + '    | ' + 'Warning: Performs Sync'.colorize(:yellow)
puts "==| Exit:   #{COMMAND_EXIT}"

while reviews.next
  next_step = if !reviews.meaning_passed? && !reviews.reading_passed?
                rand(2)
              else
                reviews.meaning_passed? ? 1 : 0
              end
  puts ''
  puts ''
  puts "==| Left: #{reviews.left} | Completed: #{reviews.completed}"
  next_color = if reviews.next_type == 'radical'
                 :blue
               else
                 reviews.next_type == 'kanji' ? :red : :green
               end

  if next_step == 1
    print "==|#{' Reading '.colorize(:white).on_black.bold}|"
    puts "#{" #{reviews.next_type}".colorize(next_color)}:"
    puts "==# #{"  #{reviews.next_word}".bold}"
  else
    print "==|#{' Meaning '.colorize(:black).on_white.bold}|"
    puts "#{" #{reviews.next_type}".colorize(next_color)}:"
    puts "==# #{"  #{reviews.next_word}".bold}"
  end

  print '==? '
  answer = gets.chomp

  case answer
  when COMMAND_EXIT
    break
  when COMMAND_REPORT
    Wanikani::LOGGER.level = Logger::INFO
    reviews.report_all
    Wanikani::LOGGER.level = Logger::UNKNOWN
    next
  when COMMAND_SYNC
    reviews.sync
    next
  else
    if next_step == 1
      puts "==| Expected: \"#{reviews.next.dig('data', 'readings').first['reading']}\""
      puts "==| Parsed as: \"#{answer.to_kana}\""
      if reviews.answer_reading(answer)
        puts "==| #{'CORRECT + + + + + + + + + + + + + + +'.colorize(:green)}"
      else
        puts "==| #{'INCORRECT - - - - - - - - - - - - - -'.colorize(:red)}"
      end
    else
      puts "==| Expected: \"#{reviews.next.dig('data', 'meanings').first['meaning']}\""
      if reviews.answer_meaning(answer)
        puts "==| #{'CORRECT + + + + + + + + + + + + + + +'.colorize(:green)}"
      else
        puts "==| #{'INCORRECT - - - - - - - - - - - - - -'.colorize(:red)}"
      end
    end
  end
end
