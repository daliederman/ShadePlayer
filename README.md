# Title: Shade Media Player
#### Video URL: 
#### Description:

Shade Media Player is intended as a lightweight and multiplatform app for casual library playback featuring tools for curation of a main shuffle selection and a variety of smart playlists.

Goals:
	- Primary, MVP: Support playback of a library of music files with specific tracks included or excluded from shuffle
		- Keep an index of media files, flexibly support importing, exporting, and handling missing entries
Stretch goals:
	- Allow smart selection of tracks with common musical components
		- eg. tempo, genre, sentiment, rating
		- Fetch data from a 3rd party API if at all possible
	- Automate playlist with broader themes using the data above
		- eg. escalation of energy (tempo in genre), 3-act (loose) "story", back-and-forth
Potential goals:
	- With user consent, network with other instances with the same tracks and anonymously recommend playlists from others' music preferences
	- Recommend tracks a user might be interested in based on the above data

#### 12/31/24 demo version:

SMP has met it's MVP goal, hooray! Shade can import audio files and manage their shuffle state. There is lots of polish that could be done, but it functions reliably and intended in its primary aspects. Some limitations of Flutter's immature ecosystem have become apparent, with some /quirks/ appearing in both the language's just_audio playback package as well as the separate just_audio_windows package. Despite these hiccups, the app is quite pleasant to use. 

I ended up using several packages from the Flutter community, including the aforementioned just_audio but also SQFLite, File_Picker, and flutter_media_metadata. I otherwise wrote the code from scratch, with some insight from Supermaven and GPT 4o, but otherwise without reference. If I continued the project I would end up having to replace much of just_audio's workings, so I may migrate to a more mature development ecosystem despite the loss of Flutter's helpful UI widgets. 

I started the project by implementing the just_audio framework, first simply hooking up its included widgets but quickly I began to customize it and tie in the custom media library objects I wrote. The program's general state is handled exclusively in main.dart, the main library object and individual media objects are defined in media_library.dart. The app's widgets frequently manipulate the library and media entries with their built in functions, but the library and media do not reach back to change the app's state. 

main.dart:
Main.dart picks up from the main player object, which is a StatefulWidget holding the data for the app as a whole. It instantiates the main library, player, and playlist immediately, and passes them to child functions as called for. I considered taking more advantage of Flutter's built in state management methods, but expediency and the somewhat limited scope of the project meant passing references directly was more practical. I used stateful updates mostly for straightforward things like iconbuttons that update simple boolean values. I initially set up some logic for supporting alternate main views, but the UI came together late due to my unfamiliarity with Flutter's rendering requirements and I haven't yet used that. Now that things are rendering making them page-dependent shouldn't have further conflicts (that's all in the Flutter demo project!). 

My library logic comes into play when the class calls initState(). I attach my listeners, sort the media for display (which is currently hardcoded but only waiting on a settings popup), shuffle the playlist, load it into the player, and load the player. At this point the app is ready to go. Due to the unexpected shuffle limitation of just_audio_windows, I also attempt to force the global shuffle state in a few ways but those functions are now vestigial. The remaining functions before building the UI are part of the just_audio boilerplate handling. 

The build method is the parent front-end of the app, setting the appearance and providing the main UI scaffold and all its children. I initially hadn't known (and didn't receive any error) that container widgets won't render unless sent a height and width, but once I had that missing piece of information I was able to display my main library. The body container often renders before the sortedMedia list is ready, so it displays a music note icon for a few frames before it loads SortedMediaList. 

Below the library display is the just_audio control bar. I started with the example implementation but quickly introduced my own widgets into its list of controls, including a display of the track title and artist, controls for previous/next track, toggling shuffle, and a platform dialog to import tracks into the app's database. Here I discovered just_audio will render and begin playing the next entry in its internal playlist before (or after) it has access to BufferingProgress, sometimes causing the control bar state to desync for the duration of the track. When this happens playback is unimpacted, and the track can be refreshed to restore normal behavior. This was where I considered switching languages.

The SortedMediaList, the main library display, is also straightforward: I adjusted the ListTiles to position track information conveniently, with the leftmost (leading) widget being the button for toggling a specific track's shuffle, and the main title/subtitle used for the track's title, artist, album, etc. I get the track duration from metadata here, in miliseconds, so I delegate the formatting of the duration display to a helper function formatDuration which I've placed in helpers_ui.dart. As expected, my onTap event cues the media entry for immediate playback. If I continue the project I'll add an onLongPress menu here for things like changing the metadata, changing queue position, deleting tracks, etc. 

media_library.dart
The MediaLibrary class is all custom logic. It maintains the master list of media while the program is running, updates when changes are made, and manages the SQL databse I use to save and load media entries. During dev/testing the DB path string is hardcoded, but making it flexible is just a matter of implementation. Because databaseFactory is platform-dependent, I've left a note that it would need to be updated to switch when running on Android or iOS. The library also keeps a sublist of media search results, but I would replace this elsewhere if I continued with writing a custom media queue. 

MediaLibrary continues with the basics: loading from the database and creating it if necessary. 
addMedia manages new and already-known media when it's provided to the app, adding it to the master media library and db as needed. 
removeMedia is much the same, though currently there's no way to call it. 
loadLibraryFile populates the master media list, loading entries from the db. I use only one table and haven't added any fancy versioning, so this is pretty straightforward SQL. Because values are returned here as nullable objects, everything gets passed as a string and parsed further if necessary.
getNext is my early attempt at custom shuffling/queuing, and supports the search list, but I ended up using just_audio's playlist for queue management until I could write a full-featured replacement.
setPlaying similarly manipulates the isPlaying field of a media entry and incremenets a track's playcount, but I replaced its use with incrementPlayCount.
toggleShuffle is the important function to record whether a media entry should be included in the global shuffle, even updating it in the database when called.
newMedia takes advantage of MetadataRetriever to fill in a media object's fields. Where entries are not null they are entered and returned with the media object.
sortBy returns a complete copy of the master media list arranged by the provided field. Entries with identical values are further sorted by a secondary attribute, producing the arrangement displayed by the main library UI. 
getShuffleable does NOT return a shuffled list of media, but returns just a list of media with a 'true' shuffle property, for use with a custom shuffling system.
incrementPlayCount records when a track has begun playing and saves that update to the db. This one took some work to listen only for when the track begins playing; I ended up going through a lot of reference reading to get the state management right. 
setupPlayCountListener is that manager. When populating the AudioPlayer I attach media entries as a tag, and this function watches the AudioPlayer to fetch the current tag (media). When the current and new tag don't match, and playback has begun, incrementPlayCount finally gets called.

The Media class. Here I store the attributes for a given file, most of them included in the embedded metadata. isPlaying and playCount are -not- metadata properties, and these I manage manually in the program and database.
toMap is a simple helper function putting the db-relevant properties into a <K,V> pair.
populateMetadata is a media object's method of filling in its own metadata, presuming it's not null.
The rest of the file is simple setters, each notifying any listeners that the value has been updated.

helpers_ui.dart:
This contains the formatDuration function, and the unused page code from before I'd determined why the library wasn't rendering at all. If I continue the project in Flutter it will likely get used in the future.