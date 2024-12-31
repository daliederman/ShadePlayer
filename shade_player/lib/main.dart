import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio/common.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shade_player/media_library.dart';
import 'package:file_picker/file_picker.dart';
import 'helpers_ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShadePlayer());
}

class ShadePlayer extends StatefulWidget {
  const ShadePlayer({super.key});

  @override
  ShadePlayerState createState() => ShadePlayerState();
}

class ShadePlayerState extends State<ShadePlayer> with WidgetsBindingObserver {
  final _player = AudioPlayer();
  final _library = Library();
  final _playlist = ConcatenatingAudioSource(
    useLazyPreparation: false,
    shuffleOrder: DefaultShuffleOrder(),
    children: [],
  );
  int iPage = 0;
  List<Media> sortedMedia = [];

  int titleWidth = 100;
  int durationWidth = 24;
  int artistWidth = 100;
  int albumWidth = 100;

  bool _isShuffleEnabled = true; // Replace with program setting
  
  @override
  void initState() {
    super.initState();
    ambiguate(WidgetsBinding.instance)!.addObserver(this);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
    ));
    _init();
  }

  Future<void> _init() async {
    // Inform the operating system of our app's audio attributes etc.
    // We pick a reasonable default for an app that plays music.
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    // Listen to errors during playback.
    _player.playbackEventStream.listen((event) {},
        onError: (Object e, StackTrace stackTrace) {
      print('A stream error occurred: $e');
    });
    try {
      _library.setupPlayCountListener(_player);
    } catch (e) {
      print("Error setting up play count listener: $e");
    }
    try {
      await _library.loadLibraryFile();
      await preparePlaylist();
    } on Exception catch (e) {
      print("Error loading library file: $e");
    }
    try {
      sortedMedia = _library.sortBy('artist');
    } on Exception catch (e) {
      print("Error loading media list: $e");
    }

    // Try to load audio from a source and catch any errors.
    try {
      // AAC example: https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.aac
      // MP3 example: https://s3.amazonaws.com/scifri-episodes/scifri20181123-episode.mp3
      //currentMedia = _library.getNext();
      //_library.setPlaying(currentMedia, true);
      //String path = currentMedia.path;
      //if (path != '') await _player.setAudioSource();
      await _player.setAudioSource(_playlist);
      await _player.load();
    } on PlayerException catch (e) {
      print("Error loading audio source: $e");
    }
  }

  Future<void> preparePlaylist() async {
    setState(() {
      sortedMedia = _library.sortBy('artist');
    });
    shufflePlaylistFresh();
  }

  Future<void> shufflePlaylistFresh() async {
    await _playlist.clear();
    for (var media in _library.mediaList) {
      if (media.shuffle == 'true' && media.path != '') {
        await _playlist.add(AudioSource.uri(Uri.file(media.path), tag: media));
        if (media.shuffle == 'true') {
          await _player.setShuffleModeEnabled(true);
          await _player.shuffle();
        }
      }
    }
  }

  // Toggle shuffle mode
  void _toggleShuffle() async {
    _isShuffleEnabled = !_isShuffleEnabled;
    await _player.setShuffleModeEnabled(_isShuffleEnabled);
    if (_isShuffleEnabled) {
      await _player.shuffle();
    }
  }

  // A brute force workaround for shuffle mode not being supported by just_audio_windows
  void _ensureShuffle() async {
    if (_isShuffleEnabled && !_player.shuffleModeEnabled) {
      await _player.setShuffleModeEnabled(true);
    }
  }

  @override
  void dispose() {
    ambiguate(WidgetsBinding.instance)!.removeObserver(this);
    // Release decoders and buffers back to the operating system making them
    // available for other apps to use.
    _player.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Release the player's resources when not in use. We use "stop" so that
      // if the app resumes later, it will still remember what position to
      // resume from.
      _player.stop();
    }
  }

  /// Collects the data useful for displaying in a seek bar, using a handy
  /// feature of rx_dart to combine the 3 streams of interest into one.
  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
          _player.positionStream,
          _player.bufferedPositionStream,
          _player.durationStream,
          (position, bufferedPosition, duration) => PositionData(
              position, bufferedPosition, duration ?? Duration.zero));

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shade Media Player',
      theme: ThemeData(
        colorScheme: ColorScheme.dark(),
        useMaterial3: true,
      ),
      
      debugShowCheckedModeBanner: false, //Places the debug stripe at the corner of the app while debugging
      home: Scaffold(
        body: sortedMedia.isEmpty
        ? Center(child: Icon(Icons.music_note, size: 200)) 
        : Container(
            alignment: Alignment.center,
            height: MediaQuery.of(context).size.height * 0.9,
            width: MediaQuery.of(context).size.width * 1,
            decoration: BoxDecoration(border: Border.all(), borderRadius: BorderRadius.circular(4)),
            child: SortedMediaList(sortedMedia, _player, _playlist, _library, shufflePlaylistFresh)
          ),
        bottomNavigationBar: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: 170,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Display play/pause button and volume/speed sliders.
                ControlButtons(_player, _library, _playlist, _toggleShuffle, _ensureShuffle, preparePlaylist),
                // Display seek bar. Using StreamBuilder, this widget rebuilds
                // each time the position, buffered position or duration changes.
                StreamBuilder<PositionData>(
                  stream: _positionDataStream,
                  builder: (context, snapshot) {
                    final positionData = snapshot.data;
                    return SeekBar(
                        duration: positionData?.duration ?? Duration.zero,
                        position: positionData?.position ?? Duration.zero,
                        bufferedPosition:
                            positionData?.bufferedPosition ?? Duration.zero,
                        onChangeEnd: _player.seek,
                    );
                  },
                ),
              ],
            ),
          ),
      ),
    );
  }
}

/// Displays the play/pause button and volume/speed sliders.
class ControlButtons extends StatelessWidget {
  final AudioPlayer player;
  final Library library;
  final ConcatenatingAudioSource playlist;
  final VoidCallback ensureShuffle;
  final VoidCallback toggleShuffle;
  final Future<void> Function() preparePlaylist;

  const ControlButtons(this.player, this.library, this.playlist, this.ensureShuffle, this.toggleShuffle, this.preparePlaylist, {super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SequenceState?>(
      stream: player.sequenceStateStream,
      builder: (context, snapshot) {
        final media = snapshot.data?.currentSource?.tag as Media?;
        return Column(
          children: [
            Text('${media?.artist} - ${media?.title}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShuffleButton(player, toggleShuffle),
                // Previous button
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: () {
                    player.seekToPrevious();
                    player.seek(Duration.zero); // Partially mitigates:
                    // [just_audio_windows]: Broadcast playback event error: Error accessing BufferingProgress. Using default value of 1. 
                  },
                ),
                // Opens volume slider dialog
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  onPressed: () {
                    showSliderDialog(
                      context: context,
                      title: "Adjust volume",
                      divisions: 10,
                      min: 0.0,
                      max: 1.0,
                      value: player.volume,
                      stream: player.volumeStream,
                      onChanged: player.setVolume,
                    );
                  },
                ),
            
                /// This StreamBuilder rebuilds whenever the player state changes, which
                /// includes the playing/paused state and also the
                /// loading/buffering/ready state. Depending on the state we show the
                /// appropriate button or loading indicator.
                StreamBuilder<PlayerState>(
                  stream: player.playerStateStream,
                  builder: (context, snapshot) {
                    final playerState = snapshot.data;
                    final processingState = playerState?.processingState;
                    final playing = playerState?.playing;
                    if (processingState == ProcessingState.loading ||
                        processingState == ProcessingState.buffering) {
                      return Container(
                        margin: const EdgeInsets.all(8.0),
                        width: 64.0,
                        height: 64.0,
                        child: const CircularProgressIndicator(),
                      );
                    } else if (playing != true) {
                      return IconButton(
                        icon: const Icon(Icons.play_arrow),
                        iconSize: 64.0,
                        onPressed: player.play,
                      );
                    } else if (processingState != ProcessingState.completed) {
                      return IconButton(
                        icon: const Icon(Icons.pause),
                        iconSize: 64.0,
                        onPressed: player.pause,
                      );
                    } else {
                      return IconButton(
                        icon: const Icon(Icons.replay),
                        iconSize: 64.0,
                        onPressed: () => player.seek(Duration.zero),
                      );
                    }
                  },
                ),
                // Opens speed slider dialog
                StreamBuilder<double>(
                  stream: player.speedStream,
                  builder: (context, snapshot) => IconButton(
                    icon: Text("${snapshot.data?.toStringAsFixed(1)}x",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      showSliderDialog(
                        context: context,
                        title: "Adjust speed",
                        divisions: 10,
                        min: 0.5,
                        max: 1.5,
                        value: player.speed,
                        stream: player.speedStream,
                        onChanged: player.setSpeed,
                      );
                    },
                  ),
                ),
                // Forward button
                IconButton(
                  icon: const Icon(Icons.fast_forward),
                  onPressed: () {
                    player.seekToNext();
                    player.seek(Duration.zero);
                  },
                ),
                // Add button
                Flex(
                  direction: Axis.horizontal,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () async {
                        FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.audio);
                        if (result != null) {
                          for (var file in result.files) {
                            library.addMedia(await library.newMedia(file.path!));
                          }
                          preparePlaylist();
                        }
                      },
                    ),
                  ]
                ),
              ],
            ),
          ],
        );
      }
    );
  }
}

class ShuffleButton extends StatelessWidget {
  final AudioPlayer player;
  final VoidCallback toggleShuffle;

  const ShuffleButton(this.player, this.toggleShuffle, {super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: player.shuffleModeEnabledStream,
      builder: (context, snapshot) {
        bool shuffleEnabled = snapshot.data ?? false;
        return IconButton(
          icon: Icon(shuffleEnabled ? Icons.shuffle : Icons.shuffle_on),
          onPressed: () {
            player.setShuffleModeEnabled(!shuffleEnabled);
            if (shuffleEnabled) {
              player.shuffle(); // Reshuffle the queue
            }
          },
        );
      },
    );
  }
}

class SortedMediaList extends StatefulWidget {
  final Library library;
  final List<Media> sortedMedia;
  final AudioPlayer player;
  final ConcatenatingAudioSource playlist;
  final Future<void> Function() shufflePlaylistFresh;

  SortedMediaList(this.sortedMedia, this.player, this.playlist, this.library, this.shufflePlaylistFresh, {super.key});

  @override
  State<SortedMediaList> createState() => _SortedMediaListState();
}

class _SortedMediaListState extends State<SortedMediaList> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.sortedMedia.length,
      itemBuilder: (context, index) {
        final media = widget.sortedMedia[index];
        return ListTile(
          leading: IconButton(
            icon: Icon(media.shuffle == 'true' ? Icons.check : Icons.check_box_outline_blank, size: 14,),
            onPressed: () {
              setState(() {
                widget.library.toggleShuffle(media);
              });
              if (media.shuffle == 'true') {
                //TODO: rebuild playlist but also restore the current track/duration
                //widget.shufflePlaylistFresh();
              }
            }
          ),
          title: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Text('${media.artist} - ${media.title}', textScaler: TextScaler.linear(0.8)),
            ],
          ),
          subtitle: Text(media.album, textScaler: TextScaler.linear(0.8),),
          trailing: Text(formatDuration(int.parse(media.duration))),
          onTap: () async {
            int? position;

            // TODO: Rebuild the playlist from the desired track

            for (int i = 0; i < widget.playlist.length; i++) {
              final source = widget.playlist[i] as UriAudioSource;
              if (source.tag == media) {
                position = i;
                break;
              }
            }

            if (position != null) {
              await widget.player.seek(Duration.zero, index: position);
              widget.player.play();
            } else {
              print('Media not found in playlist');
            }
          },
        );
      },
    );
  }
}