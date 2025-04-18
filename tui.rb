# frozen_string_literal: true

require_relative 'lib/wanikani'
require_relative 'lib/review'
require 'curses'
require 'romkan'

class WaniKaniTUI
  COMMAND_EXIT = ':q'
  COMMAND_REPORT = ':w'
  COMMAND_SYNC = ':u'

  def initialize
    @reviews = Review.new(buffer_size: 5)
    @screen = Curses.init_screen
    Curses.start_color
    Curses.noecho
    Curses.curs_set(0)
    Curses.clear
    Curses.refresh
    init_color_pairs
    main_loop
  end

  private

  def main_loop
    while @reviews.next
      structure_boxes
      fill_subject

      reading = @reviews.next_type == 'radical' ? false : reading?
      fill_ask(reading)
      refresh_boxes
      input = get_input(reading)
      case input
      when COMMAND_EXIT
        break
      when COMMAND_REPORT
        @reviews.report_all
        next
      when COMMAND_SYNC
        @reviews.sync
        next
      end
      next if reading ? @reviews.answer_reading(input) : @reviews.answer_meaning(input)

      render_details
      Curses.getch
    end
  end

  def structure_boxes(expanded: false)
    @subject_start = 0
    @subject_height = expanded ? 3 : Curses.lines - 6
    @subject = Curses::Window.new(@subject_height, Curses.cols, @subject_start, 0)

    @ask_start = @subject_height
    @ask = Curses::Window.new(3, Curses.cols, @ask_start, 0)

    @input_start = @ask_start + 3
    @input = Curses::Window.new(3, Curses.cols, @input_start, 0)

    @details_start = expanded ? @input_start + 3 : nil
    @details = expanded ? Curses::Window.new(Curses.lines - 9, Curses.cols, @details_start, 0) : nil
  end

  def refresh_boxes
    @subject.refresh
    @ask.refresh
    @input.refresh
    @details.refresh if @details
  end

  def init_color_pairs
    Curses.init_pair(1, Curses::COLOR_BLACK, Curses::COLOR_BLUE) # Radical
    Curses.init_pair(2, Curses::COLOR_BLACK, Curses::COLOR_RED) # Kanji
    Curses.init_pair(3, Curses::COLOR_BLACK, Curses::COLOR_GREEN) # Vocab
    Curses.init_pair(4, Curses::COLOR_WHITE, Curses::COLOR_BLACK) # Reading
    Curses.init_pair(5, Curses::COLOR_BLACK, Curses::COLOR_WHITE) # Meaning
  end

  def reading?
    return true if @reviews.meaning_passed?
    return false if @reviews.reading_passed?

    [true, false].sample
  end

  def fill_subject
    @subject.setpos(0, 0)
    @subject.addstr("Reviews completed: #{@reviews.completed}")
    @subject.setpos(1, 0)
    @subject.addstr("Reviews left #{@reviews.left}")
    @subject.attron(Curses::A_BOLD)
    @subject.setpos(2, 0)
    @subject.addstr(@reviews.next_type)
    @subject.attroff(Curses::A_BOLD)
    @subject.setpos(0, Curses.cols - 12)
    @subject.addstr('Exit:   :q  ')
    @subject.setpos(1, Curses.cols - 12)
    @subject.addstr('Report: :w  ')
    @subject.setpos(2, Curses.cols - 12)
    @subject.addstr('Update: :u  ')
    @subject.attron(Curses::A_BOLD)
    @subject.bkgd(Curses.color_pair(if @reviews.next_type == 'radical'
                                      1
                                    else
                                      @reviews.next_type == 'kanji' ? 2 : 3
                                    end))
    @subject.setpos(@subject_height / 2, (Curses.cols - @reviews.next_word.length) / 2)
    @subject.addstr(@reviews.next_word)
    @subject.attroff(Curses::A_BOLD)
  end

  def fill_ask(reading)
    @ask.setpos(1, (Curses.cols - 'Meaning:'.length) / 2)
    @ask.attron(Curses::A_BOLD)
    if reading
      @ask.bkgd(Curses.color_pair(4))
      @ask.addstr('Reading:')
    else
      @ask.bkgd(Curses.color_pair(5))
      @ask.addstr('Meaning:')
    end
    @ask.attroff(Curses::A_BOLD)
  end

  def get_input(reading)
    input_str = ''
    @input.clear

    while true
      @input.setpos(1, (Curses.cols - input_str.length) / 2)
      @input.addstr(input_str)
      @input.refresh

      ch = Curses.getch

      if [Curses::KEY_BACKSPACE, 127].include?(ch)
        input_str = input_str[0..-2]
        @input.clear
      elsif ch == 10
        break
      else
        input_str += ch.chr
        input_str.to_kana! if reading && !input_str.start_with?(':')
      end
    end

    input_str
  end

  def render_details
    structure_boxes(expanded: true)
    refresh_boxes
  end
end

WaniKaniTUI.new
