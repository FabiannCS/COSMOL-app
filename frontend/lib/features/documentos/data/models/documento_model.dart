import 'package:intl/intl.dart';

/// Modelo de documento individual devuelto por el BFF FastAPI.
class DocumentoModel {
  final String id;
  final String codSocio;
  final String tipoDocumento; // "FACTURA", "AVISO_COBRANZA", "AVISO_CORTE"
  final String? nroFactura;
  final String? nroFacip;
  final String? codAutorizacion;
  final String periodo;
  final int anio;
  final int mes;
  final double montoBs;
  final DateTime fechaEmision;
  final DateTime? fechaVencimiento;
  final String estadoPago; // "PENDIENTE", "PAGADO"
  final String? s3Key;
  final bool permiteDescarga;
  final String? urlDescarga;
  final String? fechaPago;

  const DocumentoModel({
    required this.id,
    required this.codSocio,
    required this.tipoDocumento,
    this.nroFactura,
    this.nroFacip,
    this.codAutorizacion,
    required this.periodo,
    required this.anio,
    required this.mes,
    required this.montoBs,
    required this.fechaEmision,
    this.fechaVencimiento,
    this.estadoPago = 'PENDIENTE',
    this.s3Key,
    this.permiteDescarga = true,
    this.urlDescarga,
    this.fechaPago,
  });

  factory DocumentoModel.fromJson(Map<String, dynamic> json) {
    return DocumentoModel(
      id: json['id']?.toString() ?? '',
      codSocio: json['cod_socio']?.toString() ?? '',
      tipoDocumento: json['tipo_documento']?.toString() ?? 'FACTURA',
      nroFactura: json['nro_factura']?.toString(),
      nroFacip: json['nro_facip']?.toString(),
      codAutorizacion: json['cod_autorizacion']?.toString(),
      periodo: json['periodo']?.toString() ?? '',
      anio: json['anio'] is int ? json['anio'] as int : int.tryParse(json['anio']?.toString() ?? '0') ?? 0,
      mes: json['mes'] is int ? json['mes'] as int : int.tryParse(json['mes']?.toString() ?? '0') ?? 0,
      montoBs: (json['monto_bs'] is num) ? (json['monto_bs'] as num).toDouble() : double.tryParse(json['monto_bs']?.toString() ?? '0.0') ?? 0.0,
      fechaEmision: json['fecha_emision'] != null
          ? DateTime.tryParse(json['fecha_emision'].toString()) ?? DateTime.now()
          : DateTime.now(),
      fechaVencimiento: json['fecha_vencimiento'] != null
          ? DateTime.tryParse(json['fecha_vencimiento'].toString())
          : null,
      estadoPago: json['estado_pago']?.toString() ?? 'PENDIENTE',
      s3Key: json['s3_key']?.toString(),
      permiteDescarga: json['permite_descarga'] == true || json['permite_descarga'] == null,
      urlDescarga: json['url_descarga']?.toString(),
      fechaPago: json['fecha_pago']?.toString() ?? json['FECHA']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cod_socio': codSocio,
      'tipo_documento': tipoDocumento,
      'nro_factura': nroFactura,
      'nro_facip': nroFacip,
      'cod_autorizacion': codAutorizacion,
      'periodo': periodo,
      'anio': anio,
      'mes': mes,
      'monto_bs': montoBs,
      'fecha_emision': DateFormat('yyyy-MM-dd').format(fechaEmision),
      'fecha_vencimiento': fechaVencimiento != null ? DateFormat('yyyy-MM-dd').format(fechaVencimiento!) : null,
      'estado_pago': estadoPago,
      's3_key': s3Key,
      'permite_descarga': permiteDescarga,
      'url_descarga': urlDescarga,
      'fecha_pago': fechaPago,
    };
  }

  DocumentoModel copyWith({
    String? id,
    String? codSocio,
    String? tipoDocumento,
    String? nroFactura,
    String? nroFacip,
    String? codAutorizacion,
    String? periodo,
    int? anio,
    int? mes,
    double? montoBs,
    DateTime? fechaEmision,
    DateTime? fechaVencimiento,
    String? estadoPago,
    String? s3Key,
    bool? permiteDescarga,
    String? urlDescarga,
    String? fechaPago,
  }) {
    return DocumentoModel(
      id: id ?? this.id,
      codSocio: codSocio ?? this.codSocio,
      tipoDocumento: tipoDocumento ?? this.tipoDocumento,
      nroFactura: nroFactura ?? this.nroFactura,
      nroFacip: nroFacip ?? this.nroFacip,
      codAutorizacion: codAutorizacion ?? this.codAutorizacion,
      periodo: periodo ?? this.periodo,
      anio: anio ?? this.anio,
      mes: mes ?? this.mes,
      montoBs: montoBs ?? this.montoBs,
      fechaEmision: fechaEmision ?? this.fechaEmision,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
      estadoPago: estadoPago ?? this.estadoPago,
      s3Key: s3Key ?? this.s3Key,
      permiteDescarga: permiteDescarga ?? this.permiteDescarga,
      urlDescarga: urlDescarga ?? this.urlDescarga,
      fechaPago: fechaPago ?? this.fechaPago,
    );
  }

  // Getters de utilidad
  bool get isFactura => tipoDocumento == 'FACTURA';
  bool get isAvisoCobranza => tipoDocumento == 'AVISO_COBRANZA';
  bool get isAvisoCorte => tipoDocumento == 'AVISO_CORTE';

  bool get isPagado {
    final e = estadoPago.trim().toUpperCase();
    return e == 'PAGADO' ||
        e == 'PAGADA' ||
        e == '1' ||
        e == 'CANCELADO' ||
        e == 'CANCELADA';
  }

  bool get isNoPagado => !isPagado;
  bool get isPendiente => !isPagado;

  String get tituloLegible {
    switch (tipoDocumento) {
      case 'FACTURA':
        return nroFactura != null && nroFactura!.isNotEmpty
            ? 'Factura N° $nroFactura'
            : 'Factura Oficial';
      case 'AVISO_COBRANZA':
        return nroFacip != null && nroFacip!.isNotEmpty
            ? 'Aviso Cobranza N° $nroFacip'
            : 'Aviso de Cobranza';
      case 'AVISO_CORTE':
        return 'Aviso de Corte';
      default:
        return 'Documento Oficial';
    }
  }

  String get periodoFormateado {
    if (periodo.isNotEmpty) {
      final parts = periodo.split('/');
      if (parts.length == 2) {
        final mesNum = int.tryParse(parts[0]);
        final anioNum = parts[1];
        if (mesNum != null && mesNum >= 1 && mesNum <= 12) {
          final nombresMeses = [
            'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
            'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
          ];
          return '${nombresMeses[mesNum - 1]} $anioNum';
        }
      }
      return periodo;
    }
    return '$mes/$anio';
  }

  String get fechaEmisionFormateada {
    return DateFormat('dd/MM/yyyy').format(fechaEmision);
  }

  String get fechaVencimientoFormateada {
    if (fechaVencimiento == null) return 'No especificada';
    return DateFormat('dd/MM/yyyy').format(fechaVencimiento!);
  }

  String get fechaPagoFormateada {
    if (fechaPago == null || fechaPago!.isEmpty) return '';
    try {
      final parsed = DateTime.parse(fechaPago!);
      return DateFormat('dd/MM/yyyy').format(parsed);
    } catch (_) {
      return fechaPago!;
    }
  }

  String get montoBsFormateado {
    final format = NumberFormat.currency(locale: 'es_BO', symbol: 'Bs', decimalDigits: 2);
    return format.format(montoBs);
  }

  String get nombreArchivoSugerido {
    final prefix = isFactura
        ? 'Factura_${nroFactura ?? periodo.replaceAll('/', '_')}'
        : isAvisoCobranza
            ? 'AvisoCobranza_${nroFacip ?? periodo.replaceAll('/', '_')}'
            : 'AvisoCorte_${periodo.replaceAll('/', '_')}';
    return 'COSMOL_${prefix}_Socio$codSocio.pdf';
  }
}

/// Modelo de colección organizada devuelta por GET /api/v1/documentos/{cod_socio}.
class ListaDocumentosModel {
  final String codSocio;
  final String rolAcceso; // "TITULAR", "CONSULTA_PAGO"
  final int totalDocumentos;
  final List<DocumentoModel> facturas;
  final List<DocumentoModel> avisosCobranza;
  final List<DocumentoModel> avisosCorte;
  final List<DocumentoModel> documentos;

  const ListaDocumentosModel({
    required this.codSocio,
    required this.rolAcceso,
    required this.totalDocumentos,
    this.facturas = const [],
    this.avisosCobranza = const [],
    this.avisosCorte = const [],
    this.documentos = const [],
  });

  factory ListaDocumentosModel.fromJson(Map<String, dynamic> json) {
    List<DocumentoModel> parseList(dynamic rawList) {
      if (rawList is List) {
        return rawList
            .whereType<Map<String, dynamic>>()
            .map((item) => DocumentoModel.fromJson(item))
            .toList();
      }
      return [];
    }

    return ListaDocumentosModel(
      codSocio: json['cod_socio']?.toString() ?? '',
      rolAcceso: json['rol_acceso']?.toString() ?? 'TITULAR',
      totalDocumentos: json['total_documentos'] is int
          ? json['total_documentos'] as int
          : int.tryParse(json['total_documentos']?.toString() ?? '0') ?? 0,
      facturas: parseList(json['facturas']),
      avisosCobranza: parseList(json['avisos_cobranza']),
      avisosCorte: parseList(json['avisos_corte']),
      documentos: parseList(json['documentos']),
    );
  }

  bool get isTitular => rolAcceso.toUpperCase() == 'TITULAR';
  bool get isInquilino => rolAcceso.toUpperCase() == 'CONSULTA_PAGO';
}

/// Estados posibles para una factura o aviso de cobranza en el módulo Documentos:
/// - pagada: Documento cancelado/pagado.
/// - impaga: Documento no pagado regular (<= 2 impagos o los 2 más recientes si hay > 2).
/// - vencida: Documento con mora que superó el umbral (antiguos si hay más de 2 impagos).
enum EstadoDocumento {
  pagada,
  impaga,
  vencida,
}

extension DocumentoListExtension on List<DocumentoModel> {
  /// Determina el estado de cobro de cada documento (Factura o Aviso de Cobranza)
  /// según las reglas de negocio de COSMOL RL:
  /// 1. Si está pagado -> EstadoDocumento.pagada
  /// 2. Si viene marcado explícitamente como VENCIDA/VENCIDO -> EstadoDocumento.vencida
  /// 3. Si no está pagado:
  ///    - Si hay más de 2 documentos no pagados en total (> 2):
  ///      Los 2 más recientes cronológicamente se mantienen como 'impaga'.
  ///      Todos los anteriores (más antiguos) pasan a ser 'vencida'.
  ///    - Si hay 2 o menos documentos no pagados (<= 2):
  ///      Todos los documentos no pagados son 'impaga'.
  EstadoDocumento obtenerEstadoDocumento(DocumentoModel doc) {
    if (doc.isPagado) {
      return EstadoDocumento.pagada;
    }

    if (doc.estadoPago.toUpperCase().contains('VENCID')) {
      return EstadoDocumento.vencida;
    }

    final unpaidItems = where((d) => !d.isAvisoCorte && !d.isPagado).toList();
    if (unpaidItems.length > 2) {
      // Ordenar cronológicamente (más antiguo primero, más reciente al final)
      final sortedUnpaid = List<DocumentoModel>.from(unpaidItems);
      sortedUnpaid.sort((a, b) {
        final cmpAnio = a.anio.compareTo(b.anio);
        if (cmpAnio != 0) return cmpAnio;
        final cmpMes = a.mes.compareTo(b.mes);
        if (cmpMes != 0) return cmpMes;
        return indexOf(a).compareTo(indexOf(b));
      });

      // Los 2 documentos no pagados más recientes se mantienen como 'impaga'
      final dosMasRecientes = sortedUnpaid.sublist(sortedUnpaid.length - 2);
      final idxDoc = indexOf(doc);

      final esDeLosDosMasRecientes = dosMasRecientes.any((d) {
        if (identical(d, doc) || d == doc) return true;
        if (idxDoc != -1 && indexOf(d) != idxDoc) return false;
        return d.id == doc.id &&
            d.periodo == doc.periodo &&
            d.anio == doc.anio &&
            d.mes == doc.mes;
      });

      if (esDeLosDosMasRecientes) {
        return EstadoDocumento.impaga;
      }

      // Todos los demás no pagados antiguos pasan a ser 'vencida'
      return EstadoDocumento.vencida;
    }

    return EstadoDocumento.impaga;
  }
}
