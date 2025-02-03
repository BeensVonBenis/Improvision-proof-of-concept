// ignore_for_file: avoid_print

import 'dart:math';
import 'dart:typed_data'; // for Uint8List
import 'dart:async'; // for Timer

import 'package:dart_melty_soundfont/preset.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'package:dart_melty_soundfont/synthesizer.dart';
import 'package:dart_melty_soundfont/synthesizer_settings.dart';
import 'package:dart_melty_soundfont/audio_renderer_ex.dart';
import 'package:dart_melty_soundfont/array_int16.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:pitchupdart/instrument_type.dart';
import 'package:pitchupdart/pitch_handler.dart';
import 'package:record/record.dart';
import 'package:tuner/home/pitch_cubit.dart';
import 'package:tuner/home/tunning_state.dart';

String asset = 'assets/TimGM6mbEdit.sf2';
int sampleRate = 44100;

void main() => runApp(const MeltyApp());

class AudioFrame {
  final Uint8List wavData;
  final int rootNote;
  final String chordType;
  final int beat;

  AudioFrame({
    required this.wavData,
    required this.rootNote,
    required this.chordType,
    required this.beat,
  });
}

class MeltyApp extends StatefulWidget {
  const MeltyApp({Key? key}) : super(key: key);

  @override
  State<MeltyApp> createState() => _MeltyAppState();
}

class _MeltyAppState extends State<MeltyApp> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    Page1(),
    Page2(),
    Page3(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AudioRecorder>(
          create: (context) => AudioRecorder(),
        ),
        RepositoryProvider<PitchDetector>(
          create: (context) => PitchDetector(),
        ),
        RepositoryProvider<PitchHandler>(
          create: (context) => PitchHandler(InstrumentType.guitar),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<PitchCubit>(
            create: (context) => PitchCubit(
              context.read<AudioRecorder>(),
              context.read<PitchDetector>(),
              context.read<PitchHandler>(),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Soundfont')),
            body: _pages[_selectedIndex],
            drawer: Drawer(
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  const DrawerHeader(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                    ),
                    child: Text('Menu'),
                  ),
                  ListTile(
                    title: const Text('Page 1'),
                    onTap: () {
                      _onItemTapped(0);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: const Text('Page 2'),
                    onTap: () {
                      _onItemTapped(1);
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: const Text('Page 3'),
                    onTap: () {
                      _onItemTapped(2);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Page1 extends StatefulWidget {
  const Page1({Key? key}) : super(key: key);

  @override
  State<Page1> createState() => _Page1State();
}

class _Page1State extends State<Page1> {
  late ChordPlayer _chordPlayer;
  final ValueNotifier<String> _chordInfoNotifier = ValueNotifier<String>("");

  @override
  void initState() {
    super.initState();
    _chordPlayer = ChordPlayer(
      asset: asset,
      sampleRate: sampleRate,
      chordProgression: [
        [69, "m7"],
        [62, "7"],
        [67, "maj7"],
        [60, "maj7"],
        [66, "mb57"],
        [59, "7"],
        [64, "m6"],
        [64, "m6"],
      ],
      chordInfoNotifier: _chordInfoNotifier,
    );
    _chordPlayer.loadSoundfont().then((_) {
      setState(() {
        _chordPlayer.soundFontLoaded = true;
      });
    });
  }

  @override
  void dispose() {
    _chordPlayer.dispose();
    _chordInfoNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (!_chordPlayer.soundFontLoaded) {
      child = const Text("initializing...");
    } else {
      child = Center(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton(
                child: Text(_chordPlayer.isPlaying ? "Pause" : "Play"),
                onPressed: () => _chordPlayer.isPlaying
                    ? _chordPlayer.pause()
                    : _chordPlayer.play(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: ValueListenableBuilder<String>(
                valueListenable: _chordInfoNotifier,
                builder: (context, value, child) {
                  return Text(
                    value,
                    textScaler: TextScaler.linear(3),
                  );
                },
              ),
            ),
            BlocBuilder<PitchCubit, TunningState>(
              builder: (context, state) {
                final int detectedNote =
                    _chordPlayer.noteNameToMidi(state.note);
                final String interval = _chordPlayer.intervalToName(
                    ((detectedNote + 12) - (_chordPlayer.root)) % 12);
                final bool isChordNote = _chordPlayer.isChordNote(detectedNote);

                return Column(
                  children: [
                    Text('Note: ${state.note}'),
                    Text('Status: ${state.status}'),
                    Text(
                      'Interval: $interval',
                      style: TextStyle(
                          color: isChordNote ? Colors.black : Colors.red),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    }
    return child;
  }
}

class Page2 extends StatelessWidget {
  const Page2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PitchCubit, TunningState>(
      builder: (context, state) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Note: ${state.note}'),
              Text('Status: ${state.status}'),
            ],
          ),
        );
      },
    );
  }
}

class ChordPlayer {
  final String asset;
  final int sampleRate;
  final List<List<dynamic>> chordProgression;
  final ValueNotifier<String> chordInfoNotifier;
  Synthesizer? _synth;
  AudioPlayer? _audioPlayer;
  Timer? _timer;

  bool isPlaying = false;
  bool soundFontLoaded = false;
  int beat = 0;
  int root = 0;
  String chordType = "";
  List<int> currentChordNotes = [];

  List<AudioFrame> _audioBuffers = [];
  int _bufferIndex = 0;

  static const int bpm = 72;
  static const double beatDuration =
      60.0 / bpm; // Duration of each beat in seconds
  static const double bufferDurationMs =
      beatDuration * 1000; // Duration in milliseconds

  int beatsPerMeasure = 4; // Time signature: 4/4
  int currentBeat = 0;

  ChordPlayer({
    required this.asset,
    required this.sampleRate,
    required this.chordProgression,
    required this.chordInfoNotifier,
  }) {
    _audioPlayer = AudioPlayer();
  }

  Future<void> loadSoundfont() async {
    ByteData bytes = await rootBundle.load(asset);
    _synth = Synthesizer.loadByteData(bytes, SynthesizerSettings());

    // print available instruments
    List<Preset> p = _synth!.soundFont.presets;
    for (int i = 0; i < p.length; i++) {
      String instrumentName =
          p[i].regions.isNotEmpty ? p[i].regions[0].instrument.name : "N/A";
      print('[preset $i] name: ${p[i].name} instrument: $instrumentName');
    }

    return Future<void>.value(null);
  }

  void dispose() {
    _timer?.cancel();
    _audioPlayer?.dispose();
  }

  Uint8List _createWavHeader(Uint8List audioBytes) {
    int totalDataLen = audioBytes.length + 36;
    int byteRate = sampleRate * 2; // 16-bit mono audio

    ByteData header = ByteData(44);
    header.setUint32(0, 0x52494646); // "RIFF"
    header.setUint32(4, totalDataLen, Endian.little);
    header.setUint32(8, 0x57415645); // "WAVE"
    header.setUint32(12, 0x666d7420); // "fmt "
    header.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    header.setUint16(20, 1, Endian.little); // AudioFormat (1 for PCM)
    header.setUint16(22, 1, Endian.little); // NumChannels (1 for mono)
    header.setUint32(24, sampleRate, Endian.little); // SampleRate
    header.setUint32(28, byteRate, Endian.little); // ByteRate
    header.setUint16(
        32, 2, Endian.little); // BlockAlign (NumChannels * BitsPerSample/8)
    header.setUint16(34, 16, Endian.little); // BitsPerSample
    header.setUint32(36, 0x64617461); // "data"
    header.setUint32(40, audioBytes.length, Endian.little); // Subchunk2Size

    return Uint8List.fromList(header.buffer.asUint8List() + audioBytes);
  }

  List<int> _generateChord(int rootNote, String chordType) {
    final Map<String, List<int>> chordIntervals = {
      'm7': [0, 3, 7, 10],
      'mb57': [0, 3, 6, 10],
      'maj7': [0, 4, 7, 11],
      '7': [0, 4, 7, 10],
      'm6': [0, 3, 7, 9],
    };

    List<int> intervals = chordIntervals[chordType] ??
        [0, 4, 7]; // Default to major chord if type not found

    return intervals.map((interval) => rootNote + interval).toList();
  }

  String midiToNoteName(int midiNumber) {
    final notes = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B'
    ];
    final octave = (midiNumber / 12).floor() - 1;
    final noteIndex = midiNumber % 12;
    return '${notes[noteIndex]}';
  }

  String intervalToName(int midiNumber) {
    final notes = [
      'I 1P 1cz',
      'ii 2m 2m',
      'II 2M 2w',
      'iii 3m 3m',
      'III 3M 3w',
      'IV 4P 4cz',
      'IV+ 4A 4zw',
      'V 5P 5cz',
      'vi 6m 6m',
      'VI 6M 6w',
      'vii 7m 7m',
      'VII 7M 7w'
    ];
    final octave = (midiNumber / 12).floor() - 1;
    final noteIndex = midiNumber % 12;
    return '${notes[noteIndex]}';
  }

  int noteNameToMidi(String noteName) {
    final notes = {
      'C': 0,
      'C#': 1,
      'D': 2,
      'D#': 3,
      'E': 4,
      'F': 5,
      'F#': 6,
      'G': 7,
      'G#': 8,
      'A': 9,
      'A#': 10,
      'B': 11
    };
    return notes[noteName] ?? 0;
  }

  bool isChordNote(int note) {
    return currentChordNotes.any((a) => a % 12 == note % 12);
  }

  void _prepareAudioBuffers() {
    _audioBuffers.clear();
    int bufferSize = (sampleRate * beatDuration).toInt();

    for (var chord in chordProgression) {
      int rootNote = chord[0];
      String chordType = chord[1];
      List<int> notes = _generateChord(rootNote, chordType);
      currentChordNotes = notes;

      for (int i = 0; i < beatsPerMeasure; i++) {
        beat = i;

        if (i == 0) {
          for (int note in notes) {
            _synth!.noteOn(channel: 0, key: note, velocity: 120);
          }
        }

        _synth!.noteOn(channel: 0, key: rootNote, velocity: 120);
        ArrayInt16 buf16 = ArrayInt16.zeros(numShorts: bufferSize);
        _synth!.renderMonoInt16(buf16);
        Uint8List audioBytes = buf16.bytes.buffer.asUint8List();
        Uint8List wavData = _createWavHeader(audioBytes);

        _audioBuffers.add(AudioFrame(
          wavData: wavData,
          rootNote: rootNote,
          chordType: chordType,
          beat: i,
        ));

        if (i == 0) {
          for (int note in notes) {
            _synth!.noteOff(channel: 0, key: note);
          }
        }
      }
    }
  }

  void _playBufferedNote() async {
    if (_audioBuffers.isNotEmpty) {
      AudioFrame frame = _audioBuffers[_bufferIndex];
      root = frame.rootNote;
      chordType = frame.chordType;
      beat = frame.beat;

      chordInfoNotifier.value =
          "${midiToNoteName(root)}$chordType ${beat + 1}/$beatsPerMeasure";

      await _audioPlayer!.setAudioSource(
        ProgressiveAudioSource(
          Uri.dataFromBytes(frame.wavData, mimeType: 'audio/wav'),
        ),
      );
      await _audioPlayer!.play();
      _bufferIndex = (_bufferIndex + 1) % _audioBuffers.length;
      currentBeat = (currentBeat + 1) % beatsPerMeasure;
    }
  }

  Future<void> play() async {
    isPlaying = true;

    // turnOff all notes
    _synth!.noteOffAll();

    // select preset (i.e. instrument)
    _synth!.selectPreset(channel: 0, preset: 0);

    _prepareAudioBuffers();

    _timer = Timer.periodic(Duration(milliseconds: bufferDurationMs.toInt()),
        (timer) {
      if (isPlaying) {
        _playBufferedNote();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> pause() async {
    await _audioPlayer?.pause();
    isPlaying = false;
    _timer?.cancel();
  }
}

class Page3 extends StatefulWidget {
  const Page3({Key? key}) : super(key: key);

  @override
  State<Page3> createState() => _Page3State();
}

class _Page3State extends State<Page3> {
  final List<String> notes = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B'
  ];
  final Random _random = Random();
  int _currentNoteIndex = 0;
  String _currentNote = '';
  String _message = '';
  String _message2 = '';

  @override
  void initState() {
    super.initState();
    _generateRandomNote();
  }

  void _generateRandomNote() {
    setState(() {
      _currentNoteIndex = _random.nextInt(notes.length);
      _currentNote = notes[_currentNoteIndex];
      _message = 'Guess the note for index $_currentNoteIndex';
    });
  }

  void _checkGuess(String note) {
    setState(() {
      if (note == _currentNote) {
        _message2 = 'Correct! The note is $note';
      } else {
        _message2 = 'Incorrect. Try again!';
      }
    });
    _generateRandomNote();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_message),
          Text(_message2),
          Wrap(
            spacing: 10.0,
            children: notes.map((note) {
              return ElevatedButton(
                onPressed: () => _checkGuess(note),
                child: Text(note),
              );
            }).toList(),
          ),
          ElevatedButton(
            onPressed: _generateRandomNote,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}
