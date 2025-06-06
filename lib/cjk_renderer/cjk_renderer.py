import os
import sys
import json
import argparse
from typing import Tuple, List, Optional, Any

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from PIL.Image import Resampling


class CJKRenderer:
    """Multiline CJK character renderer."""

    DEFAULT_FONT = "NotoSansJP-Regular.ttf"
    BRAILLE_WEIGHTS = [[1, 8], [2, 16], [4, 32], [64, 128]]

    def __init__(self, font_path: Optional[str] = None):
        """Initialize renderer with optional custom font."""
        self.font_path = font_path or os.path.join(os.path.dirname(__file__), self.DEFAULT_FONT)

    def load_font(self, size: int) -> ImageFont.FreeTypeFont:
        """Load TrueType font with graceful error handling."""
        try:
            return ImageFont.truetype(self.font_path, size=size)
        except OSError:
            sys.exit(f"Error: Cannot load font '{self.font_path}'")

    def render_character_to_image(self, char: str, size: int) -> Image.Image:
        """Render single character to centered PIL Image."""
        image = Image.new("L", (size, size), color=255)
        draw = ImageDraw.Draw(image)
        font = self.load_font(size)

        bbox = draw.textbbox((0, 0), char, font=font)
        text_width, text_height = bbox[2] - bbox[0], bbox[3] - bbox[1]

        # Center the character
        x = (size - text_width) // 2 - bbox[0]
        y = (size - text_height) // 2 - bbox[1]
        draw.text((x, y), char, font=font, fill=0)

        return image

    @staticmethod
    def image_to_binary_matrix(image: Image.Image) -> List[List[int]]:
        """Convert PIL Image to binary matrix (0=white, 1=black)."""
        return (np.array(image) < 128).astype(int).tolist()

    def matrix_to_braille(self, matrix: List[List[int]]) -> List[List[str]]:
        """Convert binary matrix to Unicode braille characters."""
        height, width = len(matrix), len(matrix[0])
        result = []

        for row_block in range(0, height, 4):
            result_row = []
            for col_block in range(0, width, 2):
                # Calculate braille dot pattern
                total = 0
                for i in range(4):
                    for j in range(2):
                        y, x = row_block + i, col_block + j
                        if y < height and x < width and matrix[y][x]:
                            total += self.BRAILLE_WEIGHTS[i][j]

                result_row.append(chr(0x2800 + total))
            result.append(result_row)

        return result

    def render_to_matrix(self, char: str, base_size: int, ratio: Tuple[int, int]) -> List[List[int]]:
        """Render CJK character to binary matrix with custom aspect ratio."""
        square_size = base_size * max(ratio)
        image = self.render_character_to_image(char, square_size)

        # Stretch to target dimensions
        target_width, target_height = base_size * ratio[0], base_size * ratio[1]
        stretched = image.resize((target_width, target_height), resample=Resampling.NEAREST)

        return self.image_to_binary_matrix(stretched)

    def render_to_braille(self, char: str, base_size: int) -> List[List[str]]:
        """Render CJK character to Unicode braille matrix."""
        image = self.render_character_to_image(char, base_size * 4)
        matrix = self.image_to_binary_matrix(image)
        return self.matrix_to_braille(matrix)

    def render_text(self, text: str, base_size: int, ratio: Optional[Tuple[int, int]] = None, use_braille: bool = False) -> List[List]:
        """Render multiple characters horizontally concatenated."""
        combined_matrix: List[List[Any]] = []

        for char in text:
            if use_braille:
                char_matrix = self.render_to_braille(char, base_size)
            else:
                char_matrix = self.render_to_matrix(char, base_size, ratio or (1, 1))

            if not combined_matrix:
                combined_matrix = char_matrix
            else:
                # Horizontal concatenation
                for i in range(len(combined_matrix)):
                    combined_matrix[i].extend(char_matrix[i])

        return combined_matrix


def parse_resolution_ratio(ratio_str: str) -> Tuple[int, int]:
    """Parse resolution ratio string like '1:2' into (width, height)."""
    try:
        width, height = map(int, ratio_str.split(":"))
        if width <= 0 or height <= 0:
            raise ValueError()
        return width, height
    except ValueError:
        raise argparse.ArgumentTypeError(
            f"Invalid ratio '{ratio_str}'. Use 'width:height' format."
        )


def main() -> None:
    """CLI entry point for CJK character rendering."""
    parser = argparse.ArgumentParser(
        description="Render CJK characters to binary matrices or braille."
    )
    parser.add_argument("text", help="CJK characters to render")
    parser.add_argument("n", type=int, help="Base resolution height")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    parser.add_argument("--font", default=None, help="TrueType font file path")

    render_group = parser.add_mutually_exclusive_group()
    render_group.add_argument(
        "--resolution-ratio",
        type=parse_resolution_ratio,
        default="1:1",
        help="Aspect ratio as width:height (default: 1:1)",
    )
    render_group.add_argument(
        "--braille",
        action="store_true",
        help="Render using Unicode braille symbols"
    )

    args = parser.parse_args()

    # Create renderer and generate output
    renderer = CJKRenderer(args.font)
    matrix = renderer.render_text(
        args.text,
        args.n,
        args.resolution_ratio if not args.braille else None,
        args.braille
    )

    # Output final matrix
    if args.json:
        print(json.dumps(matrix))
    else:
        for row in matrix:
            print("".join(map(str, row)))


if __name__ == "__main__":
    main()
