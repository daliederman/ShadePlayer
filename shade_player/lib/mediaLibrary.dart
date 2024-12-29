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
  String dbPath = 'Library.db';
  final _random = Random(DateTime.now().millisecondsSinceEpoch);
  int indexShuffle = 0;
  List<Media> mediaList = [];
  List<Media> shuffleList = [];
  List<Media> searchList = [];

  void addMedia(Media media) async {
    media.populateMetadata();
    if (mediaList.contains(media)) {
      return;
    }
    var databaseFactory = databaseFactoryFfi; // Potential: Add logic for handling other platforms
    var db = await databaseFactory.openDatabase(dbPath);
    final mediaExists = await db.query('media', where: 'path = ?', whereArgs: [media.path]);
    if (mediaExists.isNotEmpty) {
      await db.close();
      return;
    }
    Map<String, dynamic> mediaMap = {
      'shuffle': media.shuffle,
      'title': media.title,
      'artist': media.artist,
      'album': media.album,
      'genre': media.genre,
      'year': media.year,
      'duration': media.duration,
      'path': media.path,
      'playCount': media.playCount,
    };
    db.insert('media', mediaMap);
    await db.close();
    mediaList.add(media);
    notifyListeners();
  }

  void removeMedia(Media media) async {
    if (mediaList.contains(media)) {
      mediaList.remove(media);
    }
    var databaseFactory = databaseFactoryFfi; // Potential: Add logic for handling other platforms
    var db = await databaseFactory.openDatabase(dbPath);
    final mediaExists = await db.query('media', where: 'path = ?', whereArgs: [media.path]);
    if (mediaExists.isEmpty) {
      await db.close();
      return;
    }
    db.delete('media', where: 'path = ?', whereArgs: [media.path]);
    await db.close();
    notifyListeners();
  }

  // Load library database and parse it into a list of media objects
  Future loadLibraryFile() async {
    var databaseFactory = databaseFactoryFfi; // Potential: Add logic for handling other platforms
    var db = await databaseFactory.openDatabase(dbPath);

    await db.execute('CREATE TABLE IF NOT EXISTS media (id INTEGER PRIMARY KEY, shuffle TEXT, title TEXT, artist TEXT, album TEXT, genre TEXT, year TEXT, duration TEXT, path TEXT, INTEGER playCount)');
    var entries = await db.query('media');
    for (var entry in entries) {
      mediaList.add(Media(entry['shuffle'].toString(), entry['title'].toString(), entry['artist'].toString(), entry['album'].toString(),
       entry['genre'].toString(), entry['year'].toString(), entry['duration'].toString(), entry['path'].toString(), false));
    }
    await db.close();
  }

  Media getNext() {
    if (mediaList.isEmpty) {
      throw Exception('No media in library');
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
}

class Media extends ChangeNotifier {
  String shuffle = 'true';
  String title = "";
  String artist = "";
  String album = "";
  String genre = "";
  String year = "";
  String duration = "";
  String path = "";
  // Potential: Support manipulating album art
  bool isPlaying;
  int playCount = 0;

  Media(this.shuffle,this.title, this.artist, this.album, this.genre, this.year, this.duration, this.path, this.isPlaying);

  void populateMetadata() async {
    final metadata = await MetadataRetriever.fromFile(File(path));
    if (metadata.trackName != null) title = metadata.trackName!;
    if (metadata.trackArtistNames != null && metadata.trackArtistNames!.length > 1) {
      artist = metadata.trackArtistNames!.join(', ');
    } else if (metadata.trackArtistNames != null && metadata.trackArtistNames!.length == 1) {
      artist = metadata.trackArtistNames!.first;
    } else if (metadata.albumArtistName != null) {
      artist = metadata.albumArtistName!;
    }
    if (metadata.albumName != null) album = metadata.albumName!;
    if (metadata.genre != null) genre = metadata.genre!;
    if (metadata.year != null) year = metadata.year!.toString();
    if (metadata.trackDuration != null) duration = metadata.trackDuration!.toString();
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