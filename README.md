# id3
A cross platform dart package to extract meta data from mp3 files.

This package contains functions that could extract meta tags from mp3
files that uses ``ID3 tag version 2.3.0`` and ``ID3 tag version 1`` to store meta data.

## Usage

```dart
import 'package:id3/id3.dart';

void main(){
  MP3Instance mp3instance = new MP3Instance("./file.mp3");

  /// parseTags() returns 
  // 'true' if successfully parsed
  // 'false' if was unable to recognize tag so can't be parsed

  if(mp3instance.parseTagsSync()){
    print(mp3instance.getMetaTags());
  }
}

/// mp3instance.getMetaTags() returns Map<String, dynamic>
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
```


## Support

- [ ] Support ID3v2.2