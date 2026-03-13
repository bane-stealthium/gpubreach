#!/usr/bin/env python3
"""
Create d_pattern.bin file filled with 'd' bytes.
Used by mem-pattern-generator to load a known pattern into GPU memory.
"""
import argparse
import sys
from pathlib import Path


def format_size(bytes_val):
    """Format byte size in human-readable form."""
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if bytes_val < 1024.0:
            return f"{bytes_val:.2f} {unit}"
        bytes_val /= 1024.0
    return f"{bytes_val:.2f} PB"


def parse_size(size_str):
    """
    Parse size string like '1GB', '512MB', '2G', etc.

    Args:
        size_str: Size string with optional unit suffix

    Returns:
        int: Size in bytes
    """
    size_str = size_str.strip().upper()

    # Extract number and unit
    num_str = ""
    unit = ""
    for char in size_str:
        if char.isdigit() or char == ".":
            num_str += char
        else:
            unit += char

    if not num_str:
        raise ValueError(f"Invalid size string: {size_str}")

    num = float(num_str)

    # Parse unit
    multipliers = {
        "B": 1,
        "K": 1024,
        "KB": 1024,
        "M": 1024**2,
        "MB": 1024**2,
        "G": 1024**3,
        "GB": 1024**3,
        "T": 1024**4,
        "TB": 1024**4,
    }

    if not unit:
        # No unit specified, assume bytes
        return int(num)

    if unit not in multipliers:
        raise ValueError(f"Unknown size unit: {unit}")

    return int(num * multipliers[unit])


def create_pattern_file(
    output_path, size_bytes, pattern=b"d", chunk_size=16 * 1024 * 1024
):
    """
    Create a binary file filled with a repeated pattern.

    Args:
        output_path: Path to output file
        size_bytes: Total file size in bytes
        pattern: Byte pattern to repeat (default: b'd')
        chunk_size: Write chunk size for efficiency (default: 16MB)
    """
    chunk = pattern * (chunk_size // len(pattern))

    print(f"Creating {output_path} ({format_size(size_bytes)})...")

    with open(output_path, "wb") as f:
        remaining = size_bytes
        written = 0

        while remaining > 0:
            block = chunk if remaining >= len(chunk) else chunk[:remaining]
            f.write(block)
            remaining -= len(block)
            written += len(block)

            # Progress indicator
            if written % (100 * 1024 * 1024) == 0 or remaining == 0:
                progress = (written / size_bytes) * 100
                print(
                    f"  Progress: {format_size(written)} / {format_size(size_bytes)} ({progress:.1f}%)"
                )

    print(f"Created {output_path} ({format_size(size_bytes)})")


def main():
    parser = argparse.ArgumentParser(
        description="Create d_pattern.bin file filled with 'd' bytes",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s                    # Create 1GB file (default)
  %(prog)s --size 2GB         # Create 2GB file
  %(prog)s --size 512MB       # Create 512MB file
  %(prog)s --output test.bin  # Custom output filename
  %(prog)s --pattern e        # Fill with 'e' instead of 'd'
        """,
    )

    parser.add_argument(
        "--size", default="1GB", help="File size (e.g., 1GB, 512MB, 2G). Default: 1GB"
    )

    parser.add_argument(
        "--output",
        default="d_pattern.bin",
        help="Output file path. Default: d_pattern.bin",
    )

    parser.add_argument(
        "--pattern",
        default="d",
        help="Byte pattern to fill (single ASCII character). Default: d",
    )

    parser.add_argument(
        "--force", action="store_true", help="Overwrite existing file without prompting"
    )

    args = parser.parse_args()

    try:
        # Parse size
        size_bytes = parse_size(args.size)

        # Validate pattern
        if len(args.pattern) != 1:
            print("Error: Pattern must be a single ASCII character", file=sys.stderr)
            sys.exit(1)

        pattern = args.pattern.encode("ascii")

        # Check if file exists
        output_path = Path(args.output)
        if output_path.exists() and not args.force:
            response = input(f"{output_path} already exists. Overwrite? [y/N]: ")
            if not response.lower().startswith("y"):
                print("Aborted.")
                sys.exit(0)

        # Create the file
        create_pattern_file(output_path, size_bytes, pattern)

    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nAborted by user")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
