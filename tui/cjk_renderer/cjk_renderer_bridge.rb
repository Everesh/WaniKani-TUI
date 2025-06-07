# frozen_string_literal: true

require 'pycall/import'

module WaniKaniTUI
  module TUI
    # Provides entrypoit to the cjk_renderer.py script
    class CJKRendererBridge
      def initialize(font_path: nil)
        PyCall.sys.path.append(__dir__)
        cjk_renderer = PyCall.import_module('cjk_renderer')

        @renderer = font_path ? cjk_renderer.CJKRenderer.new(font_path) : cjk_renderer.CJKRenderer.new
      end

      def get_braille(chars, size, zero_gap: false, size_as_width: false)
        size /= (chars.length * 2) if size_as_width
        zero_gap = false unless size_as_width # zero_gap with restricted height is just resolution downgrade
        matrix = if zero_gap
                   matrix = @renderer.render_text(chars, size, use_braille: true, no_line_spacing: true)
                 else
                   @renderer.render_text(chars, size, use_braille: true)
                 end
        deep_to_a(matrix)
      end

      def get_bitmap(chars, height, ratio)
        unless ratio.instance_of?(Array) && ratio.length == 2
          raise ArgumentError,
                'Invalid ratio, expected pair [width, height]!'
        end

        matrix = @renderer.render_text(chars, height, ratio: [ratio.first, ratio.last])
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
