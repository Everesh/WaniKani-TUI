# frozen_string_literal: true

require 'json'

module WaniKaniTUI
  module TUI
    # Provides entrypoit to the cjk_renderer.py script
    class CJKRendererBridge
      def initialize(font_path: nil)
        @font_path = font_path
        @path = File.join(__dir__, 'cjk_renderer.py')
      end

      def get_braille(chars, size, zero_gap: false, size_as_width: false)
        size /= (chars.length * 2) if size_as_width
        zero_gap = false unless size_as_width # zero_gap with restricted height is just resolution downgrade
        font_arg = @font_path ? "--font #{@font_path}" : ""
        matrix = if zero_gap
                   JSON.parse(`python #{@path} #{chars} #{size} --braille --no_line_spacing --json #{font_arg}`)
                 else
                   JSON.parse(`python #{@path} #{chars} #{size} --braille --json #{font_arg}`)
                 end
        deep_to_a(matrix)
      end

      def get_bitmap(chars, height, ratio)
        unless ratio.instance_of?(Array) && ratio.length == 2
          raise ArgumentError,
                'Invalid ratio, expected pair [width, height]!'
        end

        font_arg = @font_path ? "--font #{@font_path}" : ""
        matrix = JSON.parse(`python #{@path} #{chars} #{height} --resolution-ratio #{ratio.first}:#{ratio.last} --json #{font_arg}`)
        deep_to_a(matrix)
      end

      private

      def deep_to_a(obj)
        return obj unless obj.respond_to?(:to_a)

        obj.to_a.map { |e| deep_to_a(e) }
      end
    end
  end
end
