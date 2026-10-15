/// Minimal TrueType reader used by the build-time glyph density tool.
///
/// Enough of the spec to (a) measure advance widths and (b) rasterise simple
/// quadratic glyph outlines so character ramps can be sorted by *measured* ink
/// density instead of eyeballing. Composite glyphs and CFF outlines are
/// reported as unsupported rather than guessed at.
library;

import 'dart:typed_data';

/// Metrics, advance widths and outlines for one TrueType (`glyf`) font.
class TtfFont {
  TtfFont._({
    required this.unitsPerEm,
    required this.ascender,
    required this.descender,
    required this.advanceWidths,
    required this.contours,
    required this.charToGlyph,
    required this.name,
  });

  /// Design space units per em.
  final int unitsPerEm;

  /// Typographic ascender in design units.
  final int ascender;

  /// Typographic descender in design units (usually negative).
  final int descender;

  /// Family name read from the `name` table, or the fallback supplied.
  final String name;

  /// Glyph id -> advance width in design units.
  final Map<int, int> advanceWidths;

  /// Glyph id -> outline contours in design units.
  final Map<int, List<List<List<double>>>> contours;

  /// Unicode code point -> glyph id.
  final Map<int, int> charToGlyph;

  /// Whether this font has usable TrueType outlines.
  bool get hasOutlines => contours.isNotEmpty;

  /// Whether the font is monospaced, i.e. every measured glyph shares one
  /// advance width. Only monospaced fonts are usable for ASCII art.
  bool get isMonospace {
    final Set<int> widths = <int>{};
    for (final int code in <int>[
      0x4D, 0x49, 0x57, 0x2E, 0x20, 0x30, 0x41, 0x6D, 0x6C, //
    ]) {
      if (charToGlyph.containsKey(code)) widths.add(advanceFor(code));
    }
    return widths.length == 1;
  }

  /// Parses a TrueType font. Throws [FormatException] for CFF or TTC inputs.
  static TtfFont parse(Uint8List data, {String fallbackName = ''}) {
    if (data.length < 4) {
      throw const FormatException('Font file is too small to be a SFNT font');
    }
    final _Reader r = _Reader(data);
    final int version = r.u32();
    if (version == 0x74746366) {
      throw const FormatException(
        'TrueType Collection (.ttc) is not supported',
      );
    }
    if (version != 0x00010000 && version != 0x4F54544F) {
      throw const FormatException('Not a SFNT font');
    }
    if (version == 0x4F54544F) {
      throw const FormatException('OpenType CFF outlines are not supported');
    }
    if (data.length < 12) {
      throw const FormatException(
        'Font file is truncated before the table directory',
      );
    }

    final int numTables = r.u16();
    r.skip(6);
    final Map<String, (int, int)> tables = <String, (int, int)>{};
    for (int i = 0; i < numTables; i++) {
      final String tag = r.tag();
      r.skip(4); // checksum
      final int offset = r.u32();
      final int length = r.u32();
      tables[tag] = (offset, length);
    }
    for (final String required in <String>[
      'head',
      'hhea',
      'maxp',
      'hmtx',
      'loca',
      'glyf',
      'cmap',
    ]) {
      if (!tables.containsKey(required)) {
        throw FormatException('Missing required table: $required');
      }
    }

    r.seek(tables['head']!.$1);
    r.skip(
      4 + 4 + 4 + 4 + 2,
    ); // version, revision, checkSumAdjustment, magic, flags
    final int unitsPerEm = r.u16();

    final (int hheaOff, _) = tables['hhea']!;
    r.seek(hheaOff);
    r.skip(4); // version
    final int ascender = r.i16();
    final int descender = r.i16();
    r.skip(2); // lineGap
    final int numberOfHMetrics = r.u16();

    r.seek(tables['maxp']!.$1);
    r.skip(4); // version
    final int numGlyphs = r.u16();

    final Map<int, int> advanceWidths = <int, int>{};
    r.seek(tables['hmtx']!.$1);
    int lastAdvance = 0;
    for (int gid = 0; gid < numGlyphs; gid++) {
      if (gid < numberOfHMetrics) {
        lastAdvance = r.u16();
        r.skip(2); // leftSideBearing
      }
      advanceWidths[gid] = lastAdvance;
    }

    final bool longLoca = r.readLongLoca(tables['head']!.$1);
    r.seek(tables['loca']!.$1);
    final List<int> loca = <int>[
      for (int i = 0; i <= numGlyphs; i++) longLoca ? r.u32() : r.u16() * 2,
    ];

    final (int glyfOff, int glyfLen) = tables['glyf']!;
    final Map<int, List<List<List<double>>>> contours =
        <int, List<List<List<double>>>>{};
    for (int gid = 0; gid < numGlyphs; gid++) {
      final int start = glyfOff + loca[gid];
      final int end = gid + 1 <= numGlyphs ? glyfOff + loca[gid + 1] : start;
      if (end <= start || end > glyfOff + glyfLen) continue;
      final List<List<List<double>>>? parsed = _parseSimpleGlyph(
        data,
        start,
        end - start,
      );
      if (parsed != null && parsed.isNotEmpty) contours[gid] = parsed;
    }

    final Map<int, int> charToGlyph = <int, int>{};
    _readCmap(data, tables['cmap']!, charToGlyph);

    final String name = tables.containsKey('name')
        ? _readFamilyName(data, tables['name']!)
        : '';

    return TtfFont._(
      unitsPerEm: unitsPerEm,
      ascender: ascender,
      descender: descender,
      advanceWidths: advanceWidths,
      contours: contours,
      charToGlyph: charToGlyph,
      name: name.isEmpty ? fallbackName : name,
    );
  }

  /// Glyph id mapped for [codeUnit], or `null`.
  int? glyphIdFor(int codeUnit) => charToGlyph[codeUnit];

  /// Advance width in design units for [codeUnit].
  int advanceFor(int codeUnit) =>
      advanceWidths[charToGlyph[codeUnit] ?? -1] ?? 0;

  /// Outline contours for [codeUnit].
  ///
  /// Each point is `[x, y, onCurve]` in design units, so a rasteriser can emit
  /// true quadratic Bézier segments instead of chord approximations.
  List<List<List<double>>>? contoursFor(int codeUnit) =>
      contours[charToGlyph[codeUnit] ?? -1];

  /// Whether the font contains a glyph for [codeUnit].
  bool hasGlyphFor(int codeUnit) => charToGlyph.containsKey(codeUnit);

  /// Code points the font maps.
  Iterable<int> get mappedCodePoints => charToGlyph.keys;

  /// Line box height (ascender - descender) in design units.
  int get lineBoxHeight => ascender - descender;
}

/// `head.indexToLocFormat` lives at a fixed offset inside the table.
extension on _Reader {
  bool readLongLoca(int headOffset) {
    seek(headOffset + 50);
    return i16() == 1;
  }
}

/// Reads a simple glyph; returns `null` for empty or composite glyphs.
List<List<List<double>>>? _parseSimpleGlyph(
  Uint8List data,
  int offset,
  int len,
) {
  final _Reader r = _Reader(Uint8List.sublistView(data, offset, offset + len));
  final int numberOfContours = r.i16();
  if (numberOfContours <= 0) return null; // blank or composite
  r.skip(8); // bounds

  final List<int> endPts = <int>[
    for (int i = 0; i < numberOfContours; i++) r.u16(),
  ];
  final int numPoints = endPts.last + 1;
  if (numPoints <= 0 || r.position + 2 > r.length) return null;
  final int instrLen = r.u16();
  r.skip(instrLen);
  if (r.remaining < numPoints) return null;

  final List<int> flags = <int>[];
  while (flags.length < numPoints) {
    final int f = r.u8();
    flags.add(f);
    if ((f & 0x08) != 0) {
      final int repeat = r.u8();
      for (int i = 0; i < repeat && flags.length < numPoints; i++) {
        flags.add(f);
      }
    }
  }

  final List<double> xs = List<double>.filled(numPoints, 0);
  final List<double> ys = List<double>.filled(numPoints, 0);
  double x = 0;
  for (int i = 0; i < numPoints; i++) {
    final int f = flags[i];
    final bool shortVec = (f & 0x02) != 0;
    final bool sameOrPositive = (f & 0x10) != 0;
    if (shortVec) {
      final int v = r.u8();
      x += sameOrPositive ? v : -v;
    } else if (!sameOrPositive) {
      x += r.i16();
    }
    xs[i] = x;
  }
  double y = 0;
  for (int i = 0; i < numPoints; i++) {
    final int f = flags[i];
    final bool shortVec = (f & 0x04) != 0;
    final bool sameOrPositive = (f & 0x20) != 0;
    if (shortVec) {
      final int v = r.u8();
      y += sameOrPositive ? v : -v;
    } else if (!sameOrPositive) {
      y += r.i16();
    }
    ys[i] = y;
  }

  final List<List<List<double>>> contours = <List<List<double>>>[];
  int begin = 0;
  for (int c = 0; c < numberOfContours; c++) {
    final int end = endPts[c];
    final List<List<double>> points = <List<double>>[];
    for (int i = begin; i <= end; i++) {
      points.add(<double>[xs[i], ys[i], (flags[i] & 0x01) != 0 ? 1 : 0]);
    }
    contours.add(points);
    begin = end + 1;
  }
  return contours;
}

/// Highest-priority cmap subtable that this reader supports.
void _readCmap(
  Uint8List data,
  (int offset, int length) table,
  Map<int, int> out,
) {
  final _Reader r = _Reader(data);
  r.seek(table.$1);
  r.skip(2); // version
  final int numTables = r.u16();
  final List<(int, int, int)> candidates = <(int, int, int)>[];
  for (int i = 0; i < numTables; i++) {
    final int platform = r.u16();
    final int encoding = r.u16();
    final int sub = table.$1 + r.u32();
    candidates.add((platform, encoding, sub));
  }
  int priority((int p, int e, int o) c) {
    if (c.$1 == 0) return 5; // Unicode
    if (c.$1 == 3 && c.$2 == 10) return 4; // Windows UCS-4
    if (c.$1 == 3 && c.$2 == 1) return 3; // Windows BMP
    if (c.$1 == 2) return 0; // deprecated ISO
    return 2;
  }

  candidates.sort((a, b) => priority(b).compareTo(priority(a)));
  for (final (_, _, int sub) in candidates) {
    if (_readCmapSubtable(data, sub, out)) return;
  }
}

bool _readCmapSubtable(Uint8List data, int offset, Map<int, int> out) {
  final _Reader r = _Reader(data);
  r.seek(offset);
  final int format = r.u16();
  if (format == 4) {
    r.skip(4); // length, language
    final int segCount = r.u16() ~/ 2;
    r.skip(6); // searchRange, entryRange, rangeShift
    final List<int> endCode = <int>[for (int i = 0; i < segCount; i++) r.u16()];
    r.skip(2); // reservedPad
    final List<int> startCode = <int>[
      for (int i = 0; i < segCount; i++) r.u16(),
    ];
    final List<int> idDelta = <int>[for (int i = 0; i < segCount; i++) r.i16()];
    final int rangeOffsetPos = r.position;
    final List<int> idRangeOffset = <int>[
      for (int i = 0; i < segCount; i++) r.u16(),
    ];

    for (int seg = 0; seg < segCount; seg++) {
      if (startCode[seg] == 0xFFFF) continue;
      for (int code = startCode[seg]; code <= endCode[seg]; code++) {
        int gid;
        if (idRangeOffset[seg] == 0) {
          gid = (code + idDelta[seg]) & 0xFFFF;
        } else {
          final int addr =
              rangeOffsetPos +
              seg * 2 +
              idRangeOffset[seg] +
              (code - startCode[seg]) * 2;
          if (addr + 1 >= data.length) continue;
          gid = _Reader(data).u16At(addr);
          if (gid != 0) gid = (gid + idDelta[seg]) & 0xFFFF;
        }
        if (gid != 0) out.putIfAbsent(code, () => gid);
      }
    }
    return true;
  }
  if (format == 12) {
    r.skip(2); // reserved
    r.skip(4); // length
    final int numGroups = r.u32();
    for (int i = 0; i < numGroups; i++) {
      final int start = r.u32();
      final int end = r.u32();
      final int startGid = r.u32();
      for (int c = start; c <= end && c < 0x110000; c++) {
        out.putIfAbsent(c, () => startGid + (c - start));
      }
    }
    return true;
  }
  if (format == 6) {
    r.skip(2); // length
    r.skip(2); // language
    final int first = r.u16();
    final int count = r.u16();
    for (int i = 0; i < count; i++) {
      final int gid = r.u16();
      if (gid != 0) out.putIfAbsent(first + i, () => gid);
    }
    return true;
  }
  return false;
}

String _readFamilyName(Uint8List data, (int offset, int length) table) {
  final _Reader r = _Reader(data);
  r.seek(table.$1);
  r.skip(2); // version
  final int count = r.u16();
  final int storage = table.$1 + r.u16();
  (int, int)? nameId1;
  (int, int)? preferred;
  for (int i = 0; i < count; i++) {
    final int platform = r.u16();
    r.skip(4); // encodingID, languageID
    final int nameId = r.u16();
    final int length = r.u16();
    final int offset = r.u16(); // name records use 16-bit offsets
    if (platform != 3 && platform != 0) continue;
    final (int, int) record = (storage + offset, length);
    if (nameId == 1 && nameId1 == null) nameId1 = record;
    if (nameId == 16 && preferred == null) preferred = record;
  }
  final (int, int)? chosen = preferred ?? nameId1;
  if (chosen == null) return '';
  final List<int> bytes = <int>[];
  r.seek(chosen.$1);
  for (int i = 0; i < chosen.$2; i++) {
    bytes.add(r.u8());
  }
  final StringBuffer sb = StringBuffer();
  for (int i = 0; i + 1 < bytes.length; i += 2) {
    sb.write(String.fromCharCode((bytes[i] << 8) | bytes[i + 1]));
  }
  return sb.toString();
}

class _Reader {
  _Reader(this._data) : _bd = ByteData.sublistView(_data);

  final Uint8List _data;
  final ByteData _bd;
  int position = 0;

  int get length => _data.length;
  int get remaining => _data.length - position;

  int u8() => _data[position++];

  int u16() {
    final int v = _bd.getUint16(position);
    position += 2;
    return v;
  }

  int u16At(int addr) => _bd.getUint16(addr);

  int i16() {
    final int v = _bd.getInt16(position);
    position += 2;
    return v;
  }

  int u32() {
    final int v = _bd.getUint32(position);
    position += 4;
    return v;
  }

  String tag() {
    final String s = String.fromCharCodes(
      _data.sublist(position, position + 4),
    );
    position += 4;
    return s;
  }

  void skip(int n) => position += n;
  void seek(int n) => position = n;
}
