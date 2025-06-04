require 'pycall/import'
require_relative '../error/cant_resize_braille_font_render_error'

module WaniKaniTUI
  class CJKRendererBridge
    def initialize(font_path: nil)
      PyCall.sys.path.append(__dir__)
      cjk_renderer = PyCall.import_module('cjk_renderer')
      @renderer = cjk_renderer.CJKRenderer.new(File.join(__dir__, 'NotoSansJP-Regular.ttf'))

      @renderer = cjk_renderer.CJKRenderer.new(font_path) unless font_path.nil?
    end

    def render_text(chars, height, ratio, braille)
      unless !braille || ratio.nil?
        raise CantResizeBrailleFontRenderError,
              'Can not change width:height ratio of braille char render!'
      end

      matrix = @renderer.render_text(chars, height, ratio: [ratio.first, ratio.last], use_braille: braille)
      deep_to_a(matrix)
    end

    private

    def deep_to_a(obj)
      return obj unless obj.respond_to?(:to_a)

      obj.to_a.map { |e| deep_to_a(e) }
    end
  end
end
