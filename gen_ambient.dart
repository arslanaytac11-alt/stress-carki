import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  final sampleRate = 22050;
  final duration = 30; // seconds
  final numSamples = sampleRate * duration;
  final bitsPerSample = 16;
  final numChannels = 1;
  final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
  final blockAlign = numChannels * (bitsPerSample ~/ 8);
  final dataSize = numSamples * blockAlign;

  final buffer = ByteData(44 + dataSize);
  var offset = 0;

  // RIFF header
  void writeString(String s) {
    for (int i = 0; i < s.length; i++) {
      buffer.setUint8(offset++, s.codeUnitAt(i));
    }
  }
  void writeInt32(int v) { buffer.setInt32(offset, v, Endian.little); offset += 4; }
  void writeInt16(int v) { buffer.setInt16(offset, v, Endian.little); offset += 2; }

  writeString('RIFF');
  writeInt32(dataSize + 36);
  writeString('WAVE');
  writeString('fmt ');
  writeInt32(16);
  writeInt16(1); // PCM
  writeInt16(numChannels);
  writeInt32(sampleRate);
  writeInt32(byteRate);
  writeInt16(blockAlign);
  writeInt16(bitsPerSample);
  writeString('data');
  writeInt32(dataSize);

  // Rahatlatıcı C major pad: C3, E3, G3, C4, E4
  final freqs = [130.81, 164.81, 196.00, 261.63, 329.63];
  final amps = [0.22, 0.16, 0.16, 0.12, 0.07];
  final pi2 = 2 * pi;
  final fadeLen = sampleRate * 2; // 2 sec fade

  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    var sample = 0.0;

    for (int f = 0; f < freqs.length; f++) {
      sample += sin(pi2 * freqs[f] * t) * amps[f];
    }

    // Slow tremolo
    sample *= 0.85 + 0.15 * sin(pi2 * 0.08 * t);

    // Second layer — pentatonic shimmer
    sample += sin(pi2 * 392.0 * t) * 0.03 * sin(pi2 * 0.12 * t); // G4
    sample += sin(pi2 * 523.25 * t) * 0.02 * sin(pi2 * 0.07 * t); // C5

    // Fade in/out for seamless loop
    if (i < fadeLen) sample *= i / fadeLen;
    if (i > numSamples - fadeLen) sample *= (numSamples - i) / fadeLen;

    var val = (sample * 14000).round().clamp(-32768, 32767);
    buffer.setInt16(offset, val, Endian.little);
    offset += 2;
  }

  File('assets/audio/ambient.wav').writeAsBytesSync(buffer.buffer.asUint8List());
  print('ambient.wav created: ${44 + dataSize} bytes');
}
