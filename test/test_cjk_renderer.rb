# frozen_string_literal: true
# rubocop: disable all

require 'minitest/autorun'
require 'fileutils'

# Suppress PyCall warnings during require
original_verbose = $VERBOSE
$VERBOSE = nil

require_relative '../tui/cjk_renderer/cjk_renderer_bridge'

$VERBOSE = original_verbose

module WaniKaniTUI
  module TUI
    class TestCJKRendererBridge < Minitest::Test
      def setup
        skip "PyCall not available" unless defined?(PyCall)
      end

      def test_initialization_with_default_font
        suppress_warnings do
          bridge = CJKRendererBridge.new
          assert_instance_of CJKRendererBridge, bridge
        end
      end

      def test_initialization_with_custom_font
        custom_font = File.join(__dir__, '..', 'tui', 'cjk_renderer', 'NotoSansJP-Regular.ttf')
        if File.exist?(custom_font)
          suppress_warnings do
            bridge = CJKRendererBridge.new(font_path: custom_font)
            assert_instance_of CJKRendererBridge, bridge
          end
        else
          skip "Font file not found: #{custom_font}"
        end
      end

      def test_get_bitmap_basic_matrix
        skip_if_font_missing

        suppress_warnings do
          bridge = CJKRendererBridge.new
          result = bridge.get_bitmap('人', 8, [1, 1])

          assert_instance_of Array, result
          assert result.length > 0
          assert_instance_of Array, result.first
          result.each do |row|
            row.each do |cell|
              assert [0, 1].include?(cell), "Matrix should contain only 0s and 1s"
            end
          end
        end
      end

      def test_get_bitmap_with_aspect_ratio
        skip_if_font_missing

        suppress_warnings do
          bridge = CJKRendererBridge.new
          result = bridge.get_bitmap('漢', 8, [2, 1])

          assert_instance_of Array, result
          assert result.length > 0

          # Check that width is roughly double the height due to 2:1 ratio
          height = result.length
          width = result.first.length
          assert width > height, "Width should be greater than height for 2:1 ratio"
        end
      end

      def test_get_braille_mode
        skip_if_font_missing

        suppress_warnings do
          bridge = CJKRendererBridge.new
          result = bridge.get_braille('字', 4)

          assert_instance_of Array, result
          assert result.length > 0
          assert_instance_of Array, result.first

          # Braille characters should be strings, not integers
          result.each do |row|
            row.each do |cell|
              assert_instance_of String, cell
              # Should be in Unicode braille block (U+2800-U+28FF)
              assert cell.ord >= 0x2800 && cell.ord <= 0x28FF, "Should be braille Unicode character"
            end
          end
        end
      end

      def test_get_bitmap_multiple_characters
        skip_if_font_missing

        suppress_warnings do
          bridge = CJKRendererBridge.new
          result = bridge.get_bitmap('日本', 6, [1, 1])

          assert_instance_of Array, result
          assert result.length > 0

          # Should be wider than single character due to horizontal concatenation
          single_char = bridge.get_bitmap('日', 6, [1, 1])
          assert result.first.length > single_char.first.length, "Multiple characters should be wider"
        end
      end

      def test_get_bitmap_invalid_ratio_raises_error
        suppress_warnings do
          bridge = CJKRendererBridge.new

          assert_raises(ArgumentError) do
            bridge.get_bitmap('文', 8, [2])  # Invalid ratio - only one element
          end

          assert_raises(ArgumentError) do
            bridge.get_bitmap('文', 8, "2:1")  # Invalid ratio - string instead of array
          end
        end
      end

      def test_get_bitmap_empty_string
        skip_if_font_missing

        suppress_warnings do
          bridge = CJKRendererBridge.new
          result = bridge.get_bitmap('', 8, [1, 1])

          # Should return some kind of matrix structure
          assert_instance_of Array, result
        end
      end

      def test_get_bitmap_with_different_sizes
        skip_if_font_missing

        suppress_warnings do
          bridge = CJKRendererBridge.new

          small_result = bridge.get_bitmap('大', 4, [1, 1])
          large_result = bridge.get_bitmap('大', 12, [1, 1])

          assert large_result.length > small_result.length, "Larger size should produce larger matrix"
          assert large_result.first.length > small_result.first.length, "Larger size should produce wider matrix"
        end
      end

      def test_get_braille_with_different_sizes
        skip_if_font_missing

        suppress_warnings do
          bridge = CJKRendererBridge.new

          small_result = bridge.get_braille('小', 2)
          large_result = bridge.get_braille('小', 6)

          assert large_result.length >= small_result.length, "Larger size should produce larger or equal matrix"
        end
      end

      def test_get_bitmap_different_ratio_combinations
        skip_if_font_missing

        suppress_warnings do
          bridge = CJKRendererBridge.new

          [[1, 1], [1, 2], [2, 1], [3, 2]].each do |ratio|
            result = bridge.get_bitmap('中', 8, ratio)
            assert_instance_of Array, result
            assert result.length > 0, "Ratio #{ratio} should produce valid result"
          end
        end
      end

      def test_unicode_characters_bitmap
        skip_if_font_missing

        suppress_warnings do
          bridge = CJKRendererBridge.new

          # Test various CJK character ranges
          test_chars = ['龍', 'ひ', 'カ', '一']

          test_chars.each do |char|
            result = bridge.get_bitmap(char, 6, [1, 1])
            assert_instance_of Array, result
            assert result.length > 0, "Character '#{char}' should render successfully"
          end
        end
      end

      def test_unicode_characters_braille
        skip_if_font_missing

        suppress_warnings do
          bridge = CJKRendererBridge.new

          # Test various CJK character ranges
          test_chars = ['龍', 'ひ', 'カ', '一']

          test_chars.each do |char|
            result = bridge.get_braille(char, 4)
            assert_instance_of Array, result
            assert result.length > 0, "Character '#{char}' should render successfully in braille"
          end
        end
      end

      def test_deep_to_a_conversion
        skip_if_font_missing

        suppress_warnings do
          bridge = CJKRendererBridge.new
          result = bridge.get_bitmap('本', 6, [1, 1])

          # Verify it's pure Ruby arrays all the way down
          assert_instance_of Array, result
          result.each do |row|
            assert_instance_of Array, row
            row.each do |cell|
              assert_instance_of Integer, cell
            end
          end
        end
      end

      private

      def suppress_warnings
        old_verbose = $VERBOSE
        $VERBOSE = nil
        yield
      ensure
        $VERBOSE = old_verbose
      end

      def skip_if_font_missing
        # Skip tests if PyCall or Python dependencies are not available
        begin
          suppress_warnings do
            bridge = CJKRendererBridge.new
            bridge.get_bitmap('テ', 4, [1, 1])
          end
        rescue => e
          skip "CJK renderer not available: #{e.message}"
        end
      end
    end
  end
end
