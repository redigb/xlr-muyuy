import 'package:material_ui/material_ui.dart';

import '../models/models.dart';

class AppColors {
  AppColors._();

  static const verdePrincipal = Color(0xFF14532D);
  static const verdeSecundario = Color(0xFF22C55E);
  static const acentoNatural = Color(0xFF84CC16);
  static const tierra = Color(0xFFA16207);
  static const tecnologia = Color(0xFF0EA5E9);
  static const fondoSuave = Color(0xFFECFDF5);

  static const ink = Color(0xFF0B1F14);
  static const inkSoft = Color(0xFF486356);
  static const inkFaint = Color(0xFF7C9488);
  static const line = Color(0xFFD8EADF);
  static const white = Color(0xFFFFFFFF);
  static const superficie = Color(0xFFF8FCFA);

  static const helada = tecnologia;
  static const heladaSoft = Color(0xFFE0F2FE);
  static const seco = Color(0xFFD97706);
  static const secoSoft = Color(0xFFFEF3C7);
  static const bueno = verdeSecundario;
  static const buenoSoft = Color(0xFFDCFCE7);

  static const alerta = Color(0xFFDC2626);
  static const alertaSoft = Color(0xFFFEE2E2);
  static const pendiente = Color(0xFF94A3B8);
  static const pendienteSoft = Color(0xFFF1F5F9);

  static const agua = tecnologia;
  static const suelo = tierra;
  static const ingresos = Color(0xFFF59E0B);
  static const riesgo = verdePrincipal;

  static const gradientHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F3D23), Color(0xFF14532D), Color(0xFF1B6B3A)],
  );

  static const gradientFresh = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [verdeSecundario, acentoNatural],
  );

  static const gradientSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF4FCF7), fondoSuave],
  );

  static const gradientTech = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [tecnologia, Color(0xFF38BDF8)],
  );

  static Color estadoColor(MesEstado estado) {
    switch (estado) {
      case MesEstado.helada:
        return helada;
      case MesEstado.seco:
        return seco;
      case MesEstado.bueno:
        return bueno;
    }
  }

  static Color estadoSoft(MesEstado estado) {
    switch (estado) {
      case MesEstado.helada:
        return heladaSoft;
      case MesEstado.seco:
        return secoSoft;
      case MesEstado.bueno:
        return buenoSoft;
    }
  }

  static Color factor(String key) {
    switch (key) {
      case 'agua':
        return agua;
      case 'suelo':
        return suelo;
      case 'ingresos':
        return ingresos;
      case 'riesgo':
        return riesgo;
      default:
        return verdeSecundario;
    }
  }

  static Color confianza(String value) {
    switch (value) {
      case 'alta':
        return verdeSecundario;
      case 'media':
        return seco;
      case 'baja':
        return Color(0xFFEA580C);
      default:
        return pendiente;
    }
  }
}

class AppRadius {
  AppRadius._();

  static const xs = 10.0;
  static const sm = 14.0;
  static const md = 20.0;
  static const lg = 26.0;
  static const xl = 34.0;
}

class AppShadows {
  AppShadows._();

  static const soft = [
    BoxShadow(color: Color(0x0F14532D), blurRadius: 24, offset: Offset(0, 10)),
  ];

  static const lifted = [
    BoxShadow(color: Color(0x1A14532D), blurRadius: 34, offset: Offset(0, 18)),
  ];

  static const glow = [
    BoxShadow(color: Color(0x3322C55E), blurRadius: 26, offset: Offset(0, 10)),
  ];
}

class AppDurations {
  AppDurations._();

  static const fast = Duration(milliseconds: 180);
  static const base = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 620);
}
