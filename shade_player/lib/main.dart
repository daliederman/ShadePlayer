import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio/common.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shade_player/media_library.dart';

void main() => runApp(const ShadePlayer());

class ShadePlayer extends StatefulWidget {
  const ShadePlayer({super.key});

  @override
  ShadePlayerState createState() => ShadePlayerState();
}

class ShadePlayerState extends State<ShadePlayer> with WidgetsBindingObserver {
  final _player = AudioPlayer();
  final _library = Library();
  int indexPage = 0;
  late Media currentMedia;

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
      _library.loadLibraryFile();
    } on Exception catch (e) {
      print("Error loading library file: $e");
    }

    // Try to load audio from a source and catch any errors.
    try {
      // AAC example: https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.aac
      // MP3 example: https://s3.amazonaws.com/scifri-episodes/scifri20181123-episode.mp3
      String path = _library.getNext().path;
      if (path != '') await _player.setAudioSource(AudioSource.file(path));
    } on PlayerException catch (e) {
      print("Error loading audio source: $e");
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
        body: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            /*SafeArea(
              child: NavigationBar(
                destinations: [
                  NavigationDestination(
                    icon: Icon(Icons.disc_full), 
                    label: 'Media',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings), 
                    label: 'Settings',
                  ),
                ],
                selectedIndex: indexPage,
                onDestinationSelected: (value) {
                  setState(() {
                    indexPage = value;
                  });
                },
              ),
            ),*/
            Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Display play/pause button and volume/speed sliders.
              ControlButtons(_player),
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
            ],


        ),
      ),
    );
  }
}

/// Displays the play/pause button and volume/speed sliders.
class ControlButtons extends StatelessWidget {
  final AudioPlayer player;

  const ControlButtons(this.player, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
      ],
    );
  }
}


class ShadeMainPage extends StatefulWidget {
  const ShadeMainPage({super.key, required this.title});
  final String title;

  @override
  State<ShadeMainPage> createState() => _ShadeMainPageState();
}

class _ShadeMainPageState extends State<ShadeMainPage> {
  int indexPage = 0;

  @override
  Widget build(BuildContext context) {
    Widget page;
      switch (indexPage) {
        case 0:
          page = PageLibrary();
        case 1:
          page = PageSettings();
        default:
          throw UnimplementedError('No widget for index: $indexPage');
      }

      return LayoutBuilder(builder: (context, constraints) {
        return Scaffold(
          body:Row(
            children: [
              //SafeArea(child: child)
            ],
          )
        );
      });
  }
}

class PageLibrary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    

    // TODO: implement build
    throw UnimplementedError();
  }
}

class PageSettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    

    // TODO: implement build
    throw UnimplementedError();
  }
}