// The Library is the master list of media files the program maintains and references. 
// It changes infrequently, only when the user is adding or removing media.

// The library can be filtered to sublists in certain circumstances, such as when searching.
// These sublists are stored separately.

import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_media_metadata/flutter_media_metadata.dart';

class Library extends ChangeNotifier {
  // Generic functions and comments helpfully provided by Supermaven
  String dbPath = 'C:/Flutter/ShadePlayer/shade_player/media_library.db';
  final _random = Random(DateTime.now().millisecondsSinceEpoch);
  final databaseFactory = databaseFactoryFfi; // Potential: Add logic for handling other platforms
  late Database db;
  int indexShuffle = 0;
  List<Media> mediaList = [];
  List<Media> shuffleList = [];
  List<Media> searchList = [];

  Future<bool> loadDB() async {
    if (await databaseFactory.databaseExists(dbPath) == false) {
      print("Database file does not exist at path: $dbPath, attempting to create");
    }
    db = await databaseFactory.openDatabase(dbPath);
    await db.execute('CREATE TABLE IF NOT EXISTS media (id INTEGER PRIMARY KEY, shuffle TEXT, title TEXT, artist TEXT, album TEXT, track INTEGER, genre TEXT, year TEXT, duration TEXT, path TEXT, playcount INTEGER)');
    print('Database loaded');
    return true;
  }

  void addMedia(Media media) async {
    //await media.populateMetadata(); //Currently handled by newMedia
    if (mediaList.contains(media)) {
      print('Media already exists in library');
      return;
    }
    
    final mediaExists = await db.query('media', where: 'path = ?', whereArgs: [media.path]);
    if (mediaExists.isNotEmpty) {
      print('Media already exists in database');
      mediaList.add(media);
      return;
    } else {
      print('Adding ${media.path} to database');
    }
    Map<String, dynamic> mediaMap = {
      'shuffle': media.shuffle,
      'title': media.title,
      'artist': media.artist,
      'album': media.album,
      'track': media.track,
      'genre': media.genre,
      'year': media.year,
      'duration': media.duration,
      'path': media.path,
      'playcount': media.playCount,
    };
    for (var entry in mediaMap.entries) {
      print(entry.key);
      print(entry.value);
    }
    db.insert('media', mediaMap);
    mediaList.add(media);
    notifyListeners();
  }

  void removeMedia(Media media) async {
    if (mediaList.contains(media)) {
      mediaList.remove(media);
    }
    final mediaExists = await db.query('media', where: 'path = ?', whereArgs: [media.path]);
    if (mediaExists.isEmpty) {
      return;
    }
    db.delete('media', where: 'path = ?', whereArgs: [media.path]);
    notifyListeners();
  }

  // Load library database and parse it into a list of media objects
  Future loadLibraryFile() async {
    await loadDB();
    var dbMedia = await db.query('media');
    for (var entry in dbMedia) {
      print('Adding ${entry['path']} to media list');
      mediaList.add(Media(entry['shuffle'].toString(), entry['title'].toString(), entry['artist'].toString(), entry['album'].toString(), int.parse(entry['track'].toString()),
       entry['genre'].toString(), entry['year'].toString(), entry['duration'].toString(), entry['path'].toString(), false, int.parse(entry['playcount'].toString())));
       print('${mediaList.last.title} added to media list');
    }
  }

  Media getNext() {
    if (mediaList.isEmpty) {
      print('No media in library');
      return Media('false', '', '', '', 0, '', '', '', '', false, 0);
      //throw Exception('No media in library');
    }
    // Locate an entry on the search list that is not playing and has a shuffle value of true.
    // If no entries on the search list exist, return the first entry on the media list.
    List<Media> potentialMedia;
    if (searchList.isNotEmpty) {
      potentialMedia = searchList.where((media) => !media.isPlaying && media.shuffle == 'true').toList();
      // Handle the case where there are no shuffled media in the search list.
      if (potentialMedia.isEmpty) {
        return searchList.elementAt(_random.nextInt(searchList.length));
      }
      return potentialMedia.elementAt(_random.nextInt(potentialMedia.length));
    } else if (mediaList.isNotEmpty) {
      potentialMedia = mediaList.where((media) => !media.isPlaying && media.shuffle == 'true').toList();
      // Handle the case where there are no shuffled media in the media list.
      if (potentialMedia.isEmpty) {
        return mediaList.elementAt(_random.nextInt(mediaList.length));
      }
      return potentialMedia.elementAt(_random.nextInt(potentialMedia.length));
    } else {
      return mediaList.first;
    }
  }

  void toggleShuffle(Media media) async{
    if (media.shuffle == 'true') {
      media.shuffle = 'false';
    } else {
      media.shuffle = 'true';
    }
    final mediaExists = await db.query('media', where: 'path = ?', whereArgs: [media.path]);
    if (mediaExists.isEmpty) {
      await db.close();
      return;
    }
    // TODO: Place into separate function
    Map<String, dynamic> mediaMap = {
      'shuffle': media.shuffle,
      'title': media.title,
      'artist': media.artist,
      'album': media.album,
      'track': media.track,
      'genre': media.genre,
      'year': media.year,
      'duration': media.duration,
      'path': media.path,
      'playcount': media.playCount,
    };
    db.update('media', mediaMap, where: 'path = ?', whereArgs: [media.path]);
    notifyListeners();
  }

  Future <Media> newMedia(String path) async {
    final metadata = await MetadataRetriever.fromFile(File(path));
    Media tempMedia = Media('true', '', '', '', 0, '', '', '', path, false, 0);
    if (metadata.trackName != null) tempMedia.setTitle(metadata.trackName!);
    if (metadata.trackArtistNames != null && metadata.trackArtistNames!.length > 1) {
      tempMedia.setArtist(metadata.trackArtistNames!.join(', '));
    } else if (metadata.trackArtistNames != null && metadata.trackArtistNames!.length == 1) {
      tempMedia.setArtist(metadata.trackArtistNames!.first);
    } else if (metadata.albumArtistName != null) {
      tempMedia.setArtist(metadata.albumArtistName!);
    }
    if (metadata.albumName != null) tempMedia.setAlbum(metadata.albumName!);
    if (metadata.trackNumber != null) tempMedia.setTrack(metadata.trackNumber!);
    if (metadata.genre != null) tempMedia.setGenre(metadata.genre!);
    if (metadata.year != null) tempMedia.setYear(metadata.year!.toString());
    if (metadata.trackDuration != null) tempMedia.setDuration(metadata.trackDuration!.toString());
    return tempMedia;
  }

  List<Media> sortBy(String sortField) {
    sortField = sortField.toLowerCase();
    List<Media> sorted = List.of(mediaList);

	sorted.sort((a, b) {
		int pComparison;
		switch (sortField) {
		case 'title':
			pComparison = a.title.compareTo(b.title);
			break;
		case 'artist':
			pComparison = a.artist.compareTo(b.artist);
			break;
		case 'album':
			pComparison = a.album.compareTo(b.album);
			break;
    case 'track':
      pComparison = a.track.compareTo(b.track);
      break;
		case 'genre':
			pComparison = a.genre.compareTo(b.genre);
			break;
		case 'year':
			pComparison = a.year.compareTo(b.year);
			break;
		case 'duration':
			pComparison = int.parse(a.duration).compareTo(int.parse(b.duration));
			break;
		case 'playcount':
			pComparison = a.playCount.compareTo(b.playCount);
			break;
		default:
			throw Exception('Invalid sort field: $sortField');
		}
	
		// If primary fields are equal, sort by the secondary field
		if (pComparison == 0) {
      String secField = 'track';
      if (a.track == b.track) {
        if (a.title != b.title) {
          secField = 'title';
        } else if (a.artist != b.artist) {
          secField = 'artist';
        } else if (a.album != b.album) {
          secField = 'album';
        } else if (a.genre != b.genre) {
          secField = 'genre';
        } else if (a.year != b.year) {
          secField = 'year';
        } else if (a.duration != b.duration) {
          secField = 'duration';
        } else if (a.playCount != b.playCount) {
          secField = 'playcount';
        } else {
          // nothin, you're SOL. Your identical tracks will be random FOR ALL TIME!!!
          // Or just until I add more fields. Which is probably also indefinite.
        }
      }
		  switch (secField) {
			case 'title':
			  return a.title.compareTo(b.title);
			case 'artist':
			  return a.artist.compareTo(b.artist);
			case 'album':
			  return a.album.compareTo(b.album);
      case 'track':
        return a.track.compareTo(b.track);
			case 'genre':
			  return a.genre.compareTo(b.genre);
			case 'year':
			  return a.year.compareTo(b.year);
			case 'duration':
			  return int.parse(a.duration).compareTo(int.parse(b.duration));
			case 'playcount':
			  return a.playCount.compareTo(b.playCount);
			default:
			  throw Exception('Invalid secondary sort field: $secField');
		  }
		}
	
		return pComparison;
	});
    return sorted;
  }
}

class Media extends ChangeNotifier {
  String shuffle = 'true';
  String title = "Untitled";
  String artist = "Unknown Artist";
  String album = "Unknown Album";
  int track = 0;
  String genre = "Unknown Genre";
  String year = "Unknown Year";
  String duration = "Unknown Duration";
  String path = "";
  // Potential: Support manipulating album art
  bool isPlaying = false;
  int playCount = 0;
  
  Media(this.shuffle,this.title, this.artist, this.album, this.track,this.genre, this.year, this.duration, this.path, this.isPlaying, this.playCount);

  Future<void> populateMetadata() async {
    final metadata = await MetadataRetriever.fromFile(File(path));
    if (metadata.trackName != null) setTitle(metadata.trackName!);
    if (metadata.trackArtistNames != null && metadata.trackArtistNames!.length > 1) {
      setArtist(metadata.trackArtistNames!.join(', '));
    } else if (metadata.trackArtistNames != null && metadata.trackArtistNames!.length == 1) {
      setArtist(metadata.trackArtistNames!.first);
    } else if (metadata.albumArtistName != null) {
      setArtist(metadata.albumArtistName!);
    }
    if (metadata.albumName != null) setAlbum(metadata.albumName!);
    if (metadata.trackNumber != null) setTrack(metadata.trackNumber!);
    if (metadata.genre != null) setGenre(metadata.genre!);
    if (metadata.year != null) setYear(metadata.year!.toString());
    if (metadata.trackDuration != null) setDuration(metadata.trackDuration!.toString());
  }

  void setShuffle(String shuffle) {
    if (shuffle.toLowerCase() != 'true' && shuffle.toLowerCase() != 'false') {
      throw Exception('Shuffle must be true or false');
    }
    this.shuffle = shuffle;
    notifyListeners();
  }

  void setTitle(String title) {
    this.title = title;
    notifyListeners();
  }

  void setArtist(String artist) {
    this.artist = artist;
    notifyListeners();
  }

  void setAlbum(String album) {
    this.album = album;
    notifyListeners();
  }

  void setTrack(int track) {
    this.track = track;
    notifyListeners();
  }

  void setGenre(String genre) {
    this.genre = genre;
    notifyListeners();
  }

  void setYear(String year) {
    this.year = year;
    notifyListeners();
  }

  void setDuration(String duration) {
    this.duration = duration;
    notifyListeners();
  }

  void setPath(String path) {
    this.path = path;
    notifyListeners();
  }

  void setPlaying(bool isPlaying) {
    this.isPlaying = isPlaying;
    notifyListeners();
  }
}