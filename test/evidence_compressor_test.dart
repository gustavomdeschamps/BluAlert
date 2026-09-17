// Testes da compressão de evidência.
//
// O limite de 800 KB é do servidor; a legibilidade é da operação. Estes testes
// guardam o equilíbrio entre os dois — sobretudo o piso, que impede o
// aplicativo de "resolver" o limite entregando uma imagem inútil.
import 'dart:math';
import 'dart:typed_data';

import 'package:blualert/queue/evidence_compressor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Imagem sintética com textura fina, parecida com o que a compressão JPEG
/// enfrenta numa foto real de rachadura ou de água barrenta.
Uint8List noisyPhoto({required int width, required int height, int seed = 7}) {
  final random = Random(seed);
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(
        x,
        y,
        random.nextInt(256),
        random.nextInt(256),
        random.nextInt(256),
      );
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 100));
}

/// Imagem suave, que o JPEG comprime bem — o caso comum de uma foto já pequena.
Uint8List smoothPhoto({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, x * 255 ~/ width, y * 255 ~/ height, 128);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 85));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const compressor = EvidenceCompressor();

  group('compressão de foto', () {
    test('uma foto grande cabe no limite do servidor', () async {
      final original = noisyPhoto(width: 3000, height: 2250);
      expect(original.length, greaterThan(kPhotoByteLimit),
          reason: 'o teste precisa partir de algo acima do limite');

      final result = await compressor.compressPhoto(original);

      expect(result.byteSize, lessThanOrEqualTo(kPhotoByteLimit));
      expect(result.width, greaterThanOrEqualTo(minimumPhotoWidth),
          reason: 'não pode reduzir abaixo do piso de legibilidade');
      expect(result.quality, greaterThanOrEqualTo(minimumPhotoQuality));
    });

    test('uma foto que já cabe não é reencodificada', () async {
      final original = smoothPhoto(width: 1280, height: 960);
      expect(original.length, lessThanOrEqualTo(kPhotoByteLimit));

      final result = await compressor.compressPhoto(original);

      expect(result.bytes, same(original),
          reason: 'reencodar de graça só perderia qualidade');
    });

    test('não amplia uma foto pequena', () async {
      final original = noisyPhoto(width: 800, height: 600);

      final result = await compressor.compressPhoto(original);

      expect(result.width, lessThanOrEqualTo(800));
    });

    test('conteúdo ilegível é recusado com instrução clara', () async {
      final invalid = Uint8List.fromList(List.filled(2048, 0));

      expect(
        () => compressor.compressPhoto(invalid),
        throwsA(isA<PhotoTooLarge>().having(
          (error) => error.message,
          'mensagem',
          contains('Tire a foto novamente'),
        )),
      );
    });
  });

  group('validação de vídeo', () {
    test('aceita vídeo dentro do limite', () {
      expect(validateVideo(5 * 1024 * 1024), isNull);
      expect(validateVideo(kVideoByteLimit), isNull);
    });

    test('recusa vídeo acima do limite antes de gastar dados', () {
      final message = validateVideo(18 * 1024 * 1024);

      expect(message, isNotNull);
      expect(message, contains('18.0 MB'));
      expect(message, contains('10 MB'));
      expect(message, contains('mais curto'),
          reason: 'a pessoa precisa saber o que fazer, não só o que falhou');
    });
  });

  group('pisos de legibilidade', () {
    test('os pisos existem e são conservadores', () {
      // Se alguém baixar estes valores para "resolver" um caso difícil, a
      // evidência deixa de servir para decidir sobre risco.
      expect(minimumPhotoWidth, greaterThanOrEqualTo(1024));
      expect(minimumPhotoQuality, greaterThanOrEqualTo(60));
    });
  });
}
