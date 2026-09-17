import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Limite aceito pelo servidor para fotos.
const int kPhotoByteLimit = 800 * 1024;

/// Limite aceito pelo servidor para vídeos.
const int kVideoByteLimit = 10 * 1024 * 1024;

/// Resultado de uma compressão bem-sucedida.
@immutable
class CompressedPhoto {
  const CompressedPhoto({
    required this.bytes,
    required this.width,
    required this.height,
    required this.quality,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final int quality;

  int get byteSize => bytes.length;
}

/// Levantada quando a foto não cabe no limite sem destruir a evidência.
///
/// Preferimos recusar e explicar a comprimir até a imagem não servir mais para
/// nada: uma foto de rachadura ilegível não ajuda ninguém a decidir.
class PhotoTooLarge implements Exception {
  const PhotoTooLarge(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Comprime a foto até caber em [kPhotoByteLimit] preservando legibilidade.
///
/// A estratégia desce por degraus, do menos ao mais destrutivo:
///
/// 1. qualidade JPEG decrescente na maior dimensão aceitável;
/// 2. só então redução de resolução.
///
/// Existe um piso deliberado: nunca abaixo de [_minWidth] pixels de largura nem
/// de [_minQuality] de qualidade. Rachadura em muro, nível de água em parede,
/// fiação caída e placa de rua deixam de ser identificáveis abaixo disso, e uma
/// evidência ilegível é pior do que a recusa — a recusa a pessoa consegue
/// resolver tirando outra foto ou ligando 199.
class EvidenceCompressor {
  const EvidenceCompressor();

  static const List<int> _widths = [1600, 1280, 1024];
  static const List<int> _qualities = [85, 78, 70, 62];
  static const int _minWidth = 1024;
  static const int _minQuality = 62;

  /// Comprime [original] para JPEG dentro do limite.
  ///
  /// Roda em isolate fora dos testes para não travar a interface: decodificar e
  /// reencodificar uma foto de celular leva centenas de milissegundos.
  Future<CompressedPhoto> compressPhoto(Uint8List original) async {
    // Já cabe e é JPEG válido: não reencoda, para não perder qualidade à toa.
    if (original.length <= kPhotoByteLimit) {
      final decoded = img.decodeImage(original);
      if (decoded != null) {
        return CompressedPhoto(
          bytes: original,
          width: decoded.width,
          height: decoded.height,
          quality: 100,
        );
      }
    }
    final result = await compute(_compressInIsolate, original);
    if (result == null) {
      throw const PhotoTooLarge(
        'Não foi possível ler esta imagem. Tire a foto novamente pelo aplicativo.',
      );
    }
    if (result.byteSize > kPhotoByteLimit) {
      throw PhotoTooLarge(
        'Esta foto não cabe no limite de 800 KB sem ficar ilegível '
        '(${(result.byteSize / 1024).round()} KB no menor tamanho aceitável). '
        'Enquadre mais perto do risco e tire outra foto. Em perigo imediato, ligue 199.',
      );
    }
    return result;
  }
}

/// Executado em isolate. Precisa ser função de topo para o [compute].
CompressedPhoto? _compressInIsolate(Uint8List original) {
  final decoded = img.decodeImage(original);
  if (decoded == null) return null;

  CompressedPhoto? smallest;
  for (final width in EvidenceCompressor._widths) {
    // Nunca amplia: uma foto pequena continua no tamanho em que foi tirada.
    final resized = decoded.width > width
        ? img.copyResize(decoded,
            width: width, interpolation: img.Interpolation.average)
        : decoded;
    for (final quality in EvidenceCompressor._qualities) {
      final encoded =
          Uint8List.fromList(img.encodeJpg(resized, quality: quality));
      final candidate = CompressedPhoto(
        bytes: encoded,
        width: resized.width,
        height: resized.height,
        quality: quality,
      );
      if (encoded.length <= kPhotoByteLimit) return candidate;
      smallest = candidate;
    }
    // Chegou ao piso de resolução e qualidade: para de degradar a evidência.
    if (width <= EvidenceCompressor._minWidth) break;
  }
  return smallest;
}

/// Verifica o vídeo antes de qualquer transferência.
///
/// Não recomprimimos vídeo no aparelho: exigiria uma dependência nativa pesada
/// e o resultado seria imprevisível em aparelhos antigos. A regra é recusar
/// cedo, com instrução clara, em vez de gastar a franquia de dados de alguém
/// para descobrir no fim que o servidor recusaria.
String? validateVideo(int byteSize) {
  if (byteSize <= kVideoByteLimit) return null;
  return 'O vídeo tem ${(byteSize / (1024 * 1024)).toStringAsFixed(1)} MB e o '
      'limite é 10 MB. Grave um trecho mais curto, de até 20 segundos, '
      'mostrando o ponto de maior risco. A foto já é suficiente para o registro.';
}

/// Piso de qualidade aplicado, exposto para os testes.
@visibleForTesting
int get minimumPhotoQuality => EvidenceCompressor._minQuality;

/// Piso de resolução aplicado, exposto para os testes.
@visibleForTesting
int get minimumPhotoWidth => EvidenceCompressor._minWidth;
