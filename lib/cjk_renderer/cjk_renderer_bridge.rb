require 'pycall/import'

module WaniKaniTUI
  class CJKRendererBridge
    def initialize(font_path: nil)
      PyCall.sys.path.append(__dir__)
      cjk_renderer = PyCall.import_module('cjk_renderer')
      @renderer = cjk_renderer.CJKRenderer.new(File.join(__dir__, 'NotoSansJP-Regular.ttf'))

      @renderer = cjk_renderer.CJKRenderer.new(font_path) unless font_path.nil?
    end

    def render_text(chars, height, ratio, braille?)
      raise CantResizeBrailleFontRender, 'Can not change width:height ratio of braille char render!' unless !braille? || ratio.nil?

      matrix = @renderer.render_text(chars, height, ratio: [ratio.first, ratio.last], use_braille: braille?)
      matrix.deep_to_a
    end

    private

    def deep_to_a(obj)
      return obj unless obj.respond_to?(:to_a)

      obj.to_a.map { |e| deep_to_a(e) }
    end
  end
end
