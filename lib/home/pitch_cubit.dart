import 'dart:typed_data';

import 'package:buffered_list_stream/buffered_list_stream.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:pitchupdart/pitch_handler.dart';
import 'package:pitchupdart/tuning_status.dart';
import 'package:tuner/home/tunning_state.dart';
import 'package:record/record.dart';

class PitchCubit extends Cubit<TunningState> {
  final AudioRecorder _audioRecorder;
  final PitchDetector _pitchDetectorDart;
  final PitchHandler _pitchupDart;

  PitchCubit(this._audioRecorder, this._pitchDetectorDart, this._pitchupDart)
      : super(TunningState(note: "N/A", status: "Play something")) {
    _init();
    print("PitchCubit initialized.");
  }

  _init() async {
    print("Checking microphone permissions...");
    if (await _audioRecorder.hasPermission()) {
      print("Microphone permissions granted. Starting audio stream...");
      final recordStream = await _audioRecorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        numChannels: 1,
        bitRate: 128000,
        sampleRate: PitchDetector.DEFAULT_SAMPLE_RATE,
      ));

      var audioSampleBufferedStream = bufferedListStream(
        recordStream.map((event) {
          // print("Audio sample received: ${event.length} bytes");
          return event.toList();
        }),
        //The library converts a PCM16 to 8bits internally. So we need twice as many bytes
        PitchDetector.DEFAULT_BUFFER_SIZE * 2,
      );

      await for (var audioSample in audioSampleBufferedStream) {
        final intBuffer = Uint8List.fromList(audioSample);

        _pitchDetectorDart
            .getPitchFromIntBuffer(intBuffer)
            .then((detectedPitch) {
          if (detectedPitch.pitched) {
            // print("Pitch detected: ${detectedPitch.pitch}");
            _pitchupDart
                .handlePitch(detectedPitch.pitch)
                .then((pitchResult) => {
                      emit(TunningState(
                        note: pitchResult.note,
                        status: pitchResult.tuningStatus.getDescription(),
                      )),
                      // print(
                      //     "Detected note: ${pitchResult.note}, Status: ${pitchResult.tuningStatus.getDescription()}")
                    });
          } else {
            // print("No pitch detected.");
          }
        });
      }
    } else {
      print("Microphone permissions not granted.");
      emit(TunningState(
          note: "Error", status: "Microphone permission required"));
    }
  }
}

extension Description on TuningStatus {
  String getDescription() => switch (this) {
        TuningStatus.tuned => "Tuned",
        TuningStatus.toolow => "Too low. Tighten the string",
        TuningStatus.toohigh => "Too high. Give it some slack",
        TuningStatus.waytoolow => "Way too low. Tighten the string",
        TuningStatus.waytoohigh => "Way too high. Give it some slack",
        TuningStatus.undefined => "Note is not in the valid interval.",
      };
}
