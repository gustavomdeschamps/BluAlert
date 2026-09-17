import 'package:flutter/foundation.dart';

/// Estados possíveis de uma ocorrência na fila local.
///
/// A ordem das constantes acompanha o avanço normal do envio. A distinção entre
/// os quatro primeiros estados e [receivedByCentral] é a regra mais importante
/// do piloto: **nenhum deles pode ser apresentado como "enviado"**. Só existe
/// recebimento depois que `occurrence-confirm` verificou os objetos no Storage
/// e gravou o protocolo — ter transferido bytes não é confirmação.
enum QueueStatus {
  /// Gravada no aparelho, ainda não houve tentativa de contato com o servidor.
  savedOnDevice,

  /// Sem conexão utilizável, ou aguardando a próxima tentativa após uma falha.
  waitingConnection,

  /// Transferindo foto e vídeo para o Storage.
  uploadingMedia,

  /// Mídia transferida; aguardando a central confirmar o recebimento.
  awaitingConfirmation,

  /// Confirmada pelo servidor, com protocolo. Único estado que significa
  /// "chegou".
  receivedByCentral,

  /// Esgotou as tentativas automáticas ou foi recusada por um motivo que a
  /// pessoa precisa resolver (foto acima do limite, cadastro incompleto).
  actionRequired;

  /// Se a ocorrência ainda depende de trabalho da fila.
  bool get isPending => this != receivedByCentral && this != actionRequired;

  /// Se a fila deve tentar avançar sozinha. [actionRequired] só sai do lugar
  /// por decisão explícita da pessoa.
  bool get isAutomatic => isPending;

  /// Rótulo curto exibido na interface. Deliberadamente sem a palavra
  /// "enviado" para qualquer estado que não seja confirmação real.
  String get label => switch (this) {
        savedOnDevice => 'Salvo no aparelho',
        waitingConnection => 'Aguardando conexão',
        uploadingMedia => 'Enviando mídia',
        awaitingConfirmation => 'Aguardando confirmação',
        receivedByCentral => 'Recebido pela central',
        actionRequired => 'Precisa da sua ação',
      };

  /// Explicação honesta do que já aconteceu de fato.
  String get description => switch (this) {
        savedOnDevice =>
          'A ocorrência está guardada neste aparelho. Ainda não foi para a central.',
        waitingConnection =>
          'Sem conexão no momento. O envio continua sozinho quando a internet voltar.',
        uploadingMedia => 'Transferindo as evidências para a central.',
        awaitingConfirmation =>
          'As evidências foram transferidas. Aguardando a central confirmar o registro.',
        receivedByCentral =>
          'A central registrou a ocorrência e devolveu um protocolo.',
        actionRequired =>
          'O envio automático parou. Veja o motivo e tente novamente.',
      };
}

/// Tipo de evidência anexada.
enum EvidenceKind { photo, video }

/// Como a coordenada da ocorrência foi definida.
///
/// A distinção é operacional, não cosmética: quando a pessoa arrasta o alfinete,
/// a precisão informada pelo GPS **deixa de descrever aquele ponto**. Mostrar o
/// raio do GPS sobre um ponto escolhido à mão seria fingir precisão que não
/// existe, e a equipe usaria esse raio para planejar a busca.
enum LocationSource {
  /// Ponto exatamente como o GPS entregou, com a precisão informada por ele.
  gps('Localização do GPS'),

  /// Ponto corrigido à mão sobre o mapa. A precisão do GPS não se aplica.
  manuallyAdjusted('Ponto ajustado no mapa'),

  /// Endereço conhecido usado quando o computador de demonstração bloqueia o
  /// GPS. O servidor e o painel preservam esta origem para que um teste nunca
  /// seja confundido com uma ocorrência real.
  testAddress('Endereço fixo de teste');

  const LocationSource(this.label);
  final String label;

  bool get isManual => this != gps;
  bool get isTest => this == testAddress;
}

/// Uma evidência guardada no aparelho, com o resumo criptográfico já calculado.
///
/// O `sha256` é calculado uma única vez, na entrada da fila, e reaproveitado em
/// todas as tentativas: além de evitar reler o arquivo, garante que o servidor
/// valide exatamente o mesmo conteúdo que foi gravado localmente.
@immutable
class QueuedEvidence {
  const QueuedEvidence({
    required this.id,
    required this.occurrenceId,
    required this.kind,
    required this.localPath,
    required this.mimeType,
    required this.byteSize,
    required this.sha256,
    this.uploadedAt,
  });

  final String id;
  final String occurrenceId;
  final EvidenceKind kind;

  /// Caminho do arquivo copiado para o diretório privado do aplicativo.
  ///
  /// A cópia é obrigatória: o arquivo devolvido pela câmera fica em cache e
  /// pode ser removido pelo sistema antes de a fila conseguir enviá-lo.
  final String localPath;
  final String mimeType;
  final int byteSize;
  final String sha256;

  /// Preenchido quando o Storage aceitou o objeto. Uma retomada não reenvia o
  /// que já subiu.
  final DateTime? uploadedAt;

  bool get isUploaded => uploadedAt != null;

  QueuedEvidence copyWith({DateTime? uploadedAt}) => QueuedEvidence(
        id: id,
        occurrenceId: occurrenceId,
        kind: kind,
        localPath: localPath,
        mimeType: mimeType,
        byteSize: byteSize,
        sha256: sha256,
        uploadedAt: uploadedAt ?? this.uploadedAt,
      );
}

/// Uma ocorrência aguardando envio, com todo o estado necessário para retomar
/// de onde parou depois de o aplicativo ser fechado.
@immutable
class QueuedOccurrence {
  const QueuedOccurrence({
    required this.id,
    required this.idempotencyKey,
    required this.category,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.locationCapturedAt,
    required this.createdAt,
    required this.status,
    required this.attempts,
    this.locationSource = LocationSource.gps,
    this.lastError,
    this.nextAttemptAt,
    this.protocol,
    this.receivedAt,
    this.evidence = const [],
  });

  /// UUID gerado no cliente. É também a chave de idempotência: reenviar a mesma
  /// ocorrência nunca cria uma segunda linha no servidor.
  final String id;
  final String idempotencyKey;
  final String category;
  final String description;
  final double latitude;
  final double longitude;

  /// Precisão informada pelo GPS, em metros. Nunca é arredondada para baixo
  /// para parecer melhor do que foi.
  final double? accuracyM;

  /// Momento em que a localização foi capturada — não o momento do envio.
  final DateTime locationCapturedAt;

  /// Origem da coordenada. Ver [LocationSource].
  final LocationSource locationSource;
  final DateTime createdAt;
  final QueueStatus status;

  /// Tentativas automáticas já gastas.
  final int attempts;

  /// Última falha, em texto que a pessoa consiga entender.
  final String? lastError;

  /// Momento a partir do qual a próxima tentativa é permitida (recuo
  /// exponencial). Antes disso a fila não toca nesta ocorrência.
  final DateTime? nextAttemptAt;

  /// Protocolo devolvido pela central. Só existe com [QueueStatus.receivedByCentral].
  final String? protocol;
  final DateTime? receivedAt;

  final List<QueuedEvidence> evidence;

  bool get hasPhoto => evidence.any((item) => item.kind == EvidenceKind.photo);

  /// Se a fila pode tentar avançar esta ocorrência agora.
  bool isReady(DateTime now) {
    if (!status.isAutomatic) return false;
    final next = nextAttemptAt;
    return next == null || !next.isAfter(now);
  }

  QueuedOccurrence copyWith({
    QueueStatus? status,
    int? attempts,
    String? lastError,
    bool clearLastError = false,
    DateTime? nextAttemptAt,
    bool clearNextAttempt = false,
    String? protocol,
    DateTime? receivedAt,
    List<QueuedEvidence>? evidence,
  }) =>
      QueuedOccurrence(
        id: id,
        idempotencyKey: idempotencyKey,
        category: category,
        description: description,
        latitude: latitude,
        longitude: longitude,
        accuracyM: accuracyM,
        locationCapturedAt: locationCapturedAt,
        locationSource: locationSource,
        createdAt: createdAt,
        status: status ?? this.status,
        attempts: attempts ?? this.attempts,
        lastError: clearLastError ? null : (lastError ?? this.lastError),
        nextAttemptAt:
            clearNextAttempt ? null : (nextAttemptAt ?? this.nextAttemptAt),
        protocol: protocol ?? this.protocol,
        receivedAt: receivedAt ?? this.receivedAt,
        evidence: evidence ?? this.evidence,
      );
}

/// Política de novas tentativas.
///
/// Recuo exponencial com teto e um número máximo de tentativas — retry infinito
/// gastaria bateria e dados de alguém que pode estar numa emergência, sem
/// nunca resolver. Ao esgotar, a ocorrência vai para [QueueStatus.actionRequired]
/// e passa a depender de uma decisão da pessoa; ela **não** é descartada.
class RetryPolicy {
  const RetryPolicy({
    this.initialDelay = const Duration(seconds: 15),
    this.maxDelay = const Duration(minutes: 30),
    this.maxAttempts = 8,
  });

  final Duration initialDelay;
  final Duration maxDelay;
  final int maxAttempts;

  bool hasAttemptsLeft(int attempts) => attempts < maxAttempts;

  /// Espera antes da tentativa seguinte, dado o número de tentativas já gastas.
  Duration delayFor(int attempts) {
    if (attempts <= 0) return Duration.zero;
    // Limita o expoente antes de deslocar: com muitas tentativas o cálculo
    // estouraria o inteiro antes de o teto ser aplicado.
    final exponent = attempts - 1 > 20 ? 20 : attempts - 1;
    final scaled = initialDelay * (1 << exponent);
    return scaled > maxDelay ? maxDelay : scaled;
  }
}
