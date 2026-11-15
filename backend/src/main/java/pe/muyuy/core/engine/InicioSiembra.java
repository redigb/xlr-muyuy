package pe.muyuy.core.engine;

import pe.muyuy.core.model.Calendario;
import pe.muyuy.core.model.MesClima;

/**
 * Mes de siembra para cualquier coordenada (SPECS_v2 §4.6):
 * 0) clima templado (invierno de ≥ 3 meses seguidos con prob_helada ≥ 0.5): primer mes tras el invierno
 *    (manda la temperatura, p. ej. Iowa → mayo);
 * 1) primer mes de la racha (circular) más larga con lluvia ≥ 0.5 × ET;
 * 2) si todo el año cumple (sin estación seca): primer mes con prob_helada &lt; 0.2;
 * 3) si ningún mes cumple o todo el año es apto: mes 1.
 */
public final class InicioSiembra {

    static final double FRACCION_ET = 0.5;
    static final double HELADA_MAX = 0.2;
    static final double HELADA_INVIERNO = 0.5;
    static final int MESES_INVIERNO = 3;

    private InicioSiembra() {}

    public static int calcular(Calendario cal) {
        int trasInvierno = trasInvierno(cal);
        if (trasInvierno > 0) return trasInvierno;
        boolean[] humedo = new boolean[13];
        int humedos = 0;
        for (int m = 1; m <= 12; m++) {
            MesClima c = cal.mes(m);
            humedo[m] = c.lluviaMm() >= FRACCION_ET * c.etMm();
            if (humedo[m]) humedos++;
        }
        if (humedos == 12) {
            for (int m = 1; m <= 12; m++) if (cal.mes(m).probHelada() < HELADA_MAX) return m;
            return 1;
        }
        if (humedos == 0) return 1;

        int mejorInicio = 1, mejorLargo = 0;
        for (int m = 1; m <= 12; m++) {
            int previo = m == 1 ? 12 : m - 1;
            if (!humedo[m] || humedo[previo]) continue;      // solo inicios de racha
            int largo = 0;
            while (largo < 12 && humedo[((m - 1 + largo) % 12) + 1]) largo++;
            if (largo > mejorLargo) {
                mejorLargo = largo;
                mejorInicio = m;
            }
        }
        return mejorInicio;
    }

    /** Mes siguiente a la racha (circular) más larga de meses con helada; 0 si no hay invierno largo. */
    static int trasInvierno(Calendario cal) {
        boolean[] frio = new boolean[13];
        int frios = 0;
        for (int m = 1; m <= 12; m++) {
            frio[m] = cal.mes(m).probHelada() >= HELADA_INVIERNO;
            if (frio[m]) frios++;
        }
        if (frios < MESES_INVIERNO || frios == 12) return 0;
        int mejorFin = 0, mejorLargo = 0;
        for (int m = 1; m <= 12; m++) {
            int previo = m == 1 ? 12 : m - 1;
            if (!frio[m] || frio[previo]) continue;
            int largo = 0;
            while (largo < 12 && frio[((m - 1 + largo) % 12) + 1]) largo++;
            if (largo > mejorLargo) {
                mejorLargo = largo;
                mejorFin = ((m - 1 + largo - 1) % 12) + 1;
            }
        }
        return mejorLargo >= MESES_INVIERNO ? mejorFin % 12 + 1 : 0;
    }
}
