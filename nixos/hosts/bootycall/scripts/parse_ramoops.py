import os
import zlib

def parse_ramoops(dump_path, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    with open(dump_path, 'rb') as f:
        data = f.read()

    chunk_size = 128 * 1024 # 128 KB
    num_chunks = len(data) // chunk_size
    print(f"File size: {len(data)} bytes. Number of 128KB chunks: {num_chunks}")

    for i in range(num_chunks):
        chunk = data[i * chunk_size : (i + 1) * chunk_size]
        # Look for headers like === or ====
        header_idx = chunk.find(b'===')
        if header_idx != -1:
            header_end = chunk.find(b'\n', header_idx)
            if header_end != -1:
                header = chunk[header_idx:header_end].decode('utf-8', errors='ignore')
                print(f"Chunk {i}: Found header: {header}")

                # The content starts after the header
                content = chunk[header_end+1:]
                # Strip trailing null bytes
                content = content.rstrip(b'\x00')

                # Check if it is compressed (header ends with '-C')
                is_compressed = header.strip().endswith('-C')

                out_path = os.path.join(out_dir, f"chunk_{i:02d}_{'compressed' if is_compressed else 'raw'}.txt")
                if is_compressed:
                    try:
                        # Ramoops headers are followed by compressed data.
                        # Sometimes there are leading/trailing junk or it's raw deflate
                        # Let's try raw decompress
                        decompressed = zlib.decompress(content, -zlib.MAX_WBITS)
                        with open(out_path, 'wb') as out_f:
                            out_f.write(decompressed)
                        print(f"  Successfully decompressed to {out_path} ({len(decompressed)} bytes)")
                    except Exception as e:
                        # Try standard zlib decompress
                        try:
                            decompressed = zlib.decompress(content)
                            with open(out_path, 'wb') as out_f:
                                out_f.write(decompressed)
                            print(f"  Successfully decompressed (zlib) to {out_path} ({len(decompressed)} bytes)")
                        except Exception as e2:
                            print(f"  Failed to decompress chunk {i}: {e} / {e2}")
                            # Write raw
                            with open(out_path, 'wb') as out_f:
                                out_f.write(content)
                else:
                    with open(out_path, 'wb') as out_f:
                        out_f.write(content)
                    print(f"  Saved raw content to {out_path} ({len(content)} bytes)")
        else:
            # Check for standard persistent RAM zones (DBGC signature)
            # persistent_ram_header structure:
            # uint32_t sig;      /* 'DBGC' (0x43474244) */
            # uint32_t start;    /* offset of data */
            # uint32_t size;     /* size of data */
            if chunk.startswith(b'DBGC'):
                import struct
                sig, start, size = struct.unpack('<III', chunk[:12])
                if size > 0 and size <= chunk_size - 12:
                    content = chunk[12 : 12 + size]
                    out_path = os.path.join(out_dir, f"chunk_{i:02d}_persistent_ram.txt")
                    # Try to decompress in case it's compressed
                    try:
                        decompressed = zlib.decompress(content, -zlib.MAX_WBITS)
                        with open(out_path, 'wb') as out_f:
                            out_f.write(decompressed)
                        print(f"Chunk {i}: Extracted and decompressed persistent RAM zone ({len(decompressed)} bytes)")
                    except Exception:
                        try:
                            decompressed = zlib.decompress(content)
                            with open(out_path, 'wb') as out_f:
                                out_f.write(decompressed)
                            print(f"Chunk {i}: Extracted and decompressed (zlib) persistent RAM zone ({len(decompressed)} bytes)")
                        except Exception:
                            # Save raw
                            with open(out_path, 'wb') as out_f:
                                out_f.write(content)
                            print(f"Chunk {i}: Extracted raw persistent RAM zone ({len(content)} bytes)")
                continue

            # Let's check if there is any printable text
            # Try to see if it's the console log (which doesn't have headers)
            text_content = chunk.rstrip(b'\x00')
            if len(text_content) > 100:
                # Count printable characters
                printables = sum(1 for c in text_content if 32 <= c < 127 or c in (10, 13))
                if printables / len(text_content) > 0.8:
                    out_path = os.path.join(out_dir, f"chunk_{i:02d}_console.txt")
                    with open(out_path, 'wb') as out_f:
                        out_f.write(text_content)
                    print(f"Chunk {i}: Appears to be raw text/console. Saved to {out_path} ({len(text_content)} bytes)")

if __name__ == '__main__':
    parse_ramoops('/tmp/ramoops_dump_latest.bin', '/tmp/parsed_ramoops_latest')
