library id3;

import 'dart:io';
import 'dart:convert';

import 'src/const.dart';

class MP3Instance {
  List<int> mp3Bytes;
  Map<String, dynamic> metaTags;

  /// Member Functions
  MP3Instance(String mp3File) {
    File file = new File(mp3File);
    mp3Bytes = file.readAsBytesSync();
    this.metaTags = {};
  }

  void parseTags(){

    var _tag = mp3Bytes.sublist(0, 3);
    if (latin1.decode(_tag) == "ID3") {
      print("Supports id3v2");

      var major_v = mp3Bytes[3];
      var revision_v = mp3Bytes[4];

      var flag = mp3Bytes[5];

      print("v2.$major_v.$revision_v");

      var unsync = (0x40 & flag != 0);
      var extended = (0x20 & flag != 0);
      var experimental = (0x10 & flag != 0);

      if (extended) {
        print("Extended id3v2 tags are not supported yet!");
      } else if (unsync) {
        print("Unsync id3v2 tags are not supported yet!");
      }

      List<int> frameHeader;
      List<int> frameName;
      List<int> frameContent;
      int frameSize;
      var cb = 10;

      while(true){
        frameHeader = mp3Bytes.sublist(cb, cb + 10);
        frameName = frameHeader.sublist(0, 4);

        RegExp exp = new RegExp(r"[A-Z0-9]+");
        if(latin1.decode(frameName) != exp.stringMatch(latin1.decode(frameName))){
          break;
        }

        frameSize = parseSize(frameHeader.sublist(4, 8));
        frameContent = mp3Bytes.sublist(cb + 10, cb + 10 + frameSize);

        if(FRAMESv2_3[latin1.decode(frameName)] == FRAMESv2_3["APIC"]){
          Map<String, String> apic = {
            "mime": "",
            "textEncoding": frameContent[0].toString(),
            "picType": "",
            "description": "",
            "base64": ""
          };

          var offset = 0;

          for(int i = 1; i < frameContent.length; i++){
            if(frameContent[i] == 0){
              apic["mime"] = latin1.decode(frameContent.sublist(1, i));
              offset = i;
              break;
            }
          }
          apic["picType"] = frameContent[++offset].toString();

          print(frameContent.sublist(offset, offset + 10));
          for(int i = offset + 1; i < frameContent.length; i++){
            if(frameContent[i] == 0){
              apic["description"] = latin1.decode(frameContent.sublist(offset + 1, i));
              offset = i;
              break;
            }
          }

          apic["base64"] = base64.encode(frameContent.sublist(offset));
          this.metaTags["APIC"] = apic;

        } else {
          var tag = FRAMESv2_3[latin1.decode(frameName)] != null ? FRAMESv2_3[latin1.decode(frameName)] : latin1.decode(frameName);
          this.metaTags[tag] = latin1.decode(cleanFrame(frameContent));
        }

        cb += 10 + frameSize;
      }
    } else {
      print("ID3v2 Header not found!");
    }
  }

  Map<String, dynamic> getMetaTags() {
    return this.metaTags;
  }
}

int parseSize(List<int> block) {
  assert(block.length == 4);

  var len = block[0] << 21;
  len += block[1] << 14;
  len += block[2] << 7;
  len += block[3];

  return len;
}

List<int> cleanFrame(List<int> bytes) {
  if(bytes.length > 3){
    return bytes.sublist(3);
  } else {
    return bytes;
  }
}

List<int> removeZeros(List<int> bytes){
  return bytes.where((i) => i != 0).toList();
}