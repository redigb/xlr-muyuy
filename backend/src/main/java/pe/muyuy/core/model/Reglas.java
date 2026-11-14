package pe.muyuy.core.model;

import java.util.List;

/** data/reglas.json: parametros del motor + reglas descritas (para explicaciones). */
public record Reglas(int campanias, int mesSiembra, double toleranciaTempC,
                     double umbralProbHelada, int mesesSecosMax, double balanceMesSecoMm,
                     int aniosClimaAlta, List<Regla> reglas) {

    public record Regla(String id, String tipo, String descripcion, String porque) {}
}
