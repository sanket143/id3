library id3;

import 'dart:io';
import 'dart:convert';

import 'src/const.dart';

class MP3ParserException implements Exception {
  String cause;
  MP3ParserException(this.cause);
  String toString() {
    return this.cause;
  }
}
class _MP3FrameParser {
  List<int> buffer;
  int pos = 0;
  int lastEncoding = 0x00; // default to latin1
  _MP3FrameParser(this.buffer);
  List<int> readUntilTerminator(List<int> terminator, {bool aligned = false}) {
    if (remainingBytes == 0) {
      return [];
    }
    for (int i = pos; i < buffer.length - (terminator.length - 1); i += (aligned ? terminator.length : 1)) {
      bool foundTerminator = true;
      for (int j = 0; j < terminator.length; j++) {
        if (buffer[i + j] != terminator[j]) {
          foundTerminator = false;
          break;
        }
      }
      if (foundTerminator) {
        final start = pos;
        pos = i + terminator.length;
        return buffer.sublist(start, pos - terminator.length);
      }
    }
    throw MP3ParserException("Did not find terminator $terminator in ${buffer.sublist(pos)}");
  }
  String readLatin1String({bool terminator = true}) {
    return latin1.decode(terminator ? readUntilTerminator([0x00]) : readRemainingBytes());
  }
  String readUTF16LEString({bool terminator = true}) {
    final bytes = terminator ? readUntilTerminator([0x00, 0x00], aligned: true) : readRemainingBytes();
    final utf16les = List<int>((bytes.length / 2).ceil());
    for (int i = 0; i < bytes.length; i++) {
      if (i % 2 == 0) {
        utf16les[i ~/ 2] = bytes[i];
      }
      else {
        utf16les[i ~/ 2] |= (bytes[i] << 8);
      }
    }
    return String.fromCharCodes(utf16les);
  }
  String readUTF16BEString({bool terminator = true}) {
    final bytes = terminator ? readUntilTerminator([0x00, 0x00]) : readRemainingBytes();
    final utf16bes = List<int>((bytes.length / 2).ceil());
    for (int i = 0; i < bytes.length; i++) {
      if (i % 2 == 0) {
        utf16bes[i ~/ 2] = (bytes[i] << 8);
      }
      else {
        utf16bes[i ~/ 2] |= bytes[i];
      }
    }
    return String.fromCharCodes(utf16bes);
  }
  String readUTF16String({bool terminator = true}) {
    final bom = buffer.sublist(pos, pos + 2);
    pos += 2;
    if (bom[0] == 0xFF && bom[1] == 0xFE) {
      return readUTF16LEString(terminator: terminator);
    }
    else if (bom[0] == 0xFE && bom[1] == 0xFF) {
      return readUTF16BEString(terminator: terminator);
    }
    else if (bom[0] == 0x00 && bom[1] == 0x00) {
      return "";
    }
    else {
      throw MP3ParserException("Unknown UTF-16 BOM: $bom in ${buffer.sublist(pos - 2)}");
    }
  }
  String readUTF8String({bool terminator = true}) {
    final bytes = terminator ? readUntilTerminator([0x00]) : readRemainingBytes();
    return Utf8Decoder().convert(bytes);
  }
  void readEncoding() {
    if (buffer[pos] < 20) {
      if (lastEncoding == 0x01) {
        // Do not modify the BOM, 0x01 must apply to each field
        pos++;
      }
      else {
        lastEncoding = buffer[pos++];
      }
    }
  }
  String readString({bool terminator = true, checkEncoding: true}) {
    if (checkEncoding) {
      readEncoding();
    }
    if (lastEncoding == 0x00) {
      return readLatin1String(terminator: terminator);
    }
    else if (lastEncoding == 0x01) {
      return readUTF16String(terminator: terminator);
    }
    else if (lastEncoding == 0x02) {
      return readUTF16BEString(terminator: terminator);
    }
    else if (lastEncoding == 0x03) {
      return readUTF8String(terminator: terminator);
    }
    else {
      throw MP3ParserException("Unknown Byte-Order Marker: $lastEncoding in $buffer");
    }
  }
  List<int> readBytes(int length) {
    pos += length;
    return buffer.sublist(pos - length, pos);
  }
  List<int> readRemainingBytes() {
    return buffer.sublist(pos);
  }
  int get remainingBytes {
    return buffer.length - pos;
  }
}

class MP3Instance {
  List<int> mp3Bytes;
  Map<String, dynamic> metaTags;

  /// Member Functions
  MP3Instance(String mp3File) {
    var file = File(mp3File);
    mp3Bytes = file.readAsBytesSync();
    metaTags = {};
  }

  bool parseTagsSync() {
    var _tag;
    _tag = mp3Bytes.sublist(0, 3);

    if (latin1.decode(_tag) == 'ID3') {
      var major_v = mp3Bytes[3];
      var revision_v = mp3Bytes[4];
      var flag = mp3Bytes[5];

      var unsync = (0x40 & flag != 0);
      var extended = (0x20 & flag != 0);
      var experimental = (0x10 & flag != 0);

      metaTags['Version'] = 'v2.$major_v.$revision_v';

      if (extended) {
        print('Extended id3v2 tags are not supported yet!');
      } else if (unsync) {
        print('Unsync id3v2 tags are not supported yet!');
      } else if (experimental) {
        print('Experimental id3v2 tag');
      }

      List<int> frameHeader;
      List<int> frameName;
      List<int> frameContent;
      int frameSize;
      var cb = 10;

      while (true) {
        frameHeader = mp3Bytes.sublist(cb, cb + 10);
        frameName = frameHeader.sublist(0, 4);

        var exp = RegExp(r'[A-Z0-9]+');
        if (latin1.decode(frameName) !=
            exp.stringMatch(latin1.decode(frameName))) {
          break;
        }

        frameSize = parseSize(frameHeader.sublist(4, 8), major_v);
        frameContent = mp3Bytes.sublist(cb + 10, cb + 10 + frameSize);

        if (FRAMESv2_3[latin1.decode(frameName)] == FRAMESv2_3['APIC']) {
          var apic = {
            'mime': '',
            'textEncoding': frameContent[0].toString(),
            'picType': '',
            'description': '',
            'base64': ''
          };

          final frame = _MP3FrameParser(frameContent);
          frame.readEncoding();
          apic['mime'] = frame.readLatin1String();
          apic['description'] = frame.readString();
          apic['base64'] = base64.encode(frame.readRemainingBytes());
          metaTags['APIC'] = apic;
        } else if (FRAMESv2_3[latin1.decode(frameName)] == FRAMESv2_3['USLT']) {
          final frame = _MP3FrameParser(frameContent);
          frame.readEncoding();
          final language = latin1.decode(frame.readBytes(3));
          String contentDescriptor;
          try {
            contentDescriptor = frame.readString();
          }
          on MP3ParserException {
            contentDescriptor = frame.readString(terminator: false);
          }
          final lyrics = (frame.remainingBytes > 0) ? frame.readString(terminator: false) : contentDescriptor;
          if (frame.remainingBytes == 0) {
            contentDescriptor = '';
          }
          metaTags['USLT'] = {
            'language': language,
            'contentDescriptor': contentDescriptor,
            'lyrics': lyrics
          };
        } else if (FRAMESv2_3[latin1.decode(frameName)] == FRAMESv2_3['WXXX']) {
            final frame = _MP3FrameParser(frameContent);
            metaTags['WXXX'] = {
              'description': frame.readString(),
              'url': frame.readLatin1String(terminator: false)
            };
        } else if (FRAMESv2_3[latin1.decode(frameName)] == FRAMESv2_3['COMM']) {
            final frame = _MP3FrameParser(frameContent);
            frame.readEncoding();
            final language = latin1.decode(frame.readBytes(3));
            final shortDescription = frame.readString(checkEncoding: false);
            final text = frame.readString(terminator: false, checkEncoding: false);
            if (metaTags['COMM'] == null) {
              metaTags['COMM'] = {};
              if (metaTags['COMM'][language] == null) {
                metaTags['COMM'][language] = {};
              }
            }
            metaTags['COMM'][language][shortDescription] = text;
        } else if (FRAMESv2_3[latin1.decode(frameName)] == FRAMESv2_3['MCDI'] || FRAMESv2_3[latin1.decode(frameName)] == FRAMESv2_3['RVAD']) {
          // Binary data
		  metaTags[FRAMESv2_3[latin1.decode(frameName)] ?? latin1.decode(frameName)] = frameContent;
        } else {
          var tag =
              FRAMESv2_3[latin1.decode(frameName)] ?? latin1.decode(frameName);
          metaTags[tag] = _MP3FrameParser(frameContent).readString(terminator: false);
        }

        cb += 10 + frameSize;
      }

      return true;
    }

    var _header = mp3Bytes.sublist(mp3Bytes.length - 128, mp3Bytes.length);
    _tag = _header.sublist(0, 3);

    if (latin1.decode(_tag).toLowerCase() == 'tag') {
      metaTags['Version'] = '1.0';

      var _title = _header.sublist(3, 33);
      var _artist = _header.sublist(33, 63);
      var _album = _header.sublist(63, 93);
      var _year = _header.sublist(93, 97);
      var _comment = _header.sublist(97, 127);
      var _genre = _header[127];

      metaTags['Title'] = latin1.decode(_title).trim();
      metaTags['Artist'] = latin1.decode(_artist).trim();
      metaTags['Album'] = latin1.decode(_album).trim();
      metaTags['Year'] = latin1.decode(_year).trim();
      metaTags['Comment'] = latin1.decode(_comment).trim();
      metaTags['Genre'] = GENREv1[_genre];

      return true;
    }

    return false;
  }

  Map<String, dynamic> getMetaTags() {
    return metaTags;
  }
}

int parseSize(List<int> block, int major_v) {
  assert(block.length == 4);

  int len;
  if (major_v == 4) {
    len = block[0] << 21;
    len += block[1] << 14;
    len += block[2] << 7;
    len += block[3];
  }
  else if (major_v == 3) {
    len = block[0] << 24;
    len += block[1] << 16;
    len += block[2] << 8;
    len += block[3];
  }
  else {
    throw MP3ParserException("Unknown major version $major_v");
  }

  return len;
}

List<int> cleanFrame(List<int> bytes) {
  List<int> temp = new List<int>.from(bytes);

  temp.removeWhere((item) => item < 1); 

  if (temp.length > 3) {
    return temp.sublist(3);
  } else {
    return temp;
  }
}

List<int> removeZeros(List<int> bytes) {
  return bytes.where((i) => i != 0).toList();
}
