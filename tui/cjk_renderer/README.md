# CJK Renderer

Script to render CJK characters as binary pixel matrices or Unicode braille symbols using a TrueType font. It can be used via a command-line interface or imported as a module.

## Dependencies

*   Python 3.x
*   `Pillow`
*   `numpy`
*   A CJK TrueType font (defaults to `NotoSansJP-Regular.ttf`).

Install with `pip install Pillow numpy`.

## Command-Line Usage

Render "人" as a 16x16 bitmap:
```/dev/null/path.extension
python cjk_renderer.py 人 16
```
Render "文字" as braille:
```/dev/null/path.extension
python cjk_renderer.py 文字 8 --braille
```

See `python cjk_renderer.py -h` for all options.

## Module Usage

Import and use the `CJKRenderer` class:

```python /dev/null/path.extension
from cjk_renderer import CJKRenderer

renderer = CJKRenderer() # Or CJKRenderer(font_path="...")

bitmap_matrix = renderer.render_text("你好", 16)
braille_matrix = renderer.render_text("文字", 8, use_braille=True)

# matrices are list of lists (int for bitmap, char for braille)
```
---

Will probably be rewritten in Rust to allow for simplier single file packaging of the top level project
