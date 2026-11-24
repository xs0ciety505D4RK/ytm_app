import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Jembatan ke notifikasi & lock screen (foreground service Android).
/// Tombol next/prev di notifikasi diteruskan ke PlayerService.
class MusicHandler extends BaseAudioHandler with SeekHandler {
  MusicHandler(this.player, {required this.onNext, required this.onPrev}) {
    player.playbackEventStream.listen((_) => _publishState());
    player.playerStateStream.listen((_) => _publishState());
  }

  final AudioPlayer player;
  final Future<void> Function() onNext;
  final Future<void> Function() onPrev;

  void _publishState() => playbackState.add(_state());

  PlaybackState _state() => PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          player.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[player.processingState]!,
        playing: player.playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
      );

  @override
  Future<void> play() => player.play();
  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> seek(Duration position) => player.seek(position);
  @override
  Future<void> skipToNext() => onNext();
  @override
  Future<void> skipToPrevious() => onPrev();
  @override
  Future<void> stop() async {
    await player.stop();
    return super.stop();
  }
}
