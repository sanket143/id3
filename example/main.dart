import 'dart:io';
import 'package:id3/id3.dart';

void main(){
  List<int> mp3Bytes = File("./file.mp3").readAsBytesSync(); 
  MP3Instance mp3instance = new MP3Instance(mp3Bytes);
  if(mp3instance.parseTagsSync()){
    print(mp3instance.getMetaTags());
  }
}

// {
//   "Title": "SongName",
//   "Artist": "ArtistName",
//   "Album": "AlbumName",
//   "APIC": {
//     "mime": "image/jpeg",
//     "textEncoding": "0",
//     "picType": "0",
//     "description": "description",
//     "base64": "AP/Y/+AAEEpGSUYAAQEBAE..."
//   }
// }