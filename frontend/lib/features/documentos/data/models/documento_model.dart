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
    };
  }

  // Getters de utilidad
  bool get isFactura => tipoDocumento == 'FACTURA';
  bool get isAvisoCobranza => tipoDocumento == 'AVISO_COBRANZA';
  bool get isAvisoCorte => tipoDocumento == 'AVISO_CORTE';

  bool get isPagado => estadoPago.toUpperCase() == 'PAGADO';
  bool get isPendiente => estadoPago.toUpperCase() == 'PENDIENTE';

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
