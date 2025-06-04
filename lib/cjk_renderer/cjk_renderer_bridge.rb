# frozen_string_literal: true

require 'pycall/import'

module WaniKaniTUI
  class CJKRendererBridge
    def initialize(font_path: nil)
      PyCall.sys.path.append(__dir__)
      cjk_renderer = PyCall.import_module('cjk_renderer')
      
      default_font = File.join(__dir__, 'NotoSansJP-Regular.ttf')
      font_to_use = font_path || default_font
      
      @renderer = cjk_renderer.CJKRenderer.new(font_to_use)
    end

    def get_braille(chars, height)
      matrix = @renderer.render_text(chars, height, use_braille: true)
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
