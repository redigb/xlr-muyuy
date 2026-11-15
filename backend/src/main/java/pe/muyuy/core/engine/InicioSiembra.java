package pe.muyuy.core.engine;

import pe.muyuy.core.model.Calendario;
import pe.muyuy.core.model.MesClima;

/**
 * Mes de siembra para cualquier coordenada (SPECS_v2 §4.6):
 * 1) primer mes de la racha (circular) más larga con lluvia ≥ 0.5 × ET;
 * 2) si todo el año cumple (sin estación seca): primer mes con prob_helada &lt; 0.2;
 * 3) si ningún mes cumple o todo el año es apto: mes 1.
 */
public final class InicioSiembra {

    static final double FRACCION_ET = 0.5;
    static final double HELADA_MAX = 0.2;

    private InicioSiembra() {}

    public static int calcular(Calendario cal) {
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
}
