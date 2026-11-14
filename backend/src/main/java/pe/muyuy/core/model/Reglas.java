package pe.muyuy.core.model;

import java.util.List;

/** data/reglas.json: parámetros del motor + reglas descritas. */
public record Reglas(int campanias, int mesSiembra, double toleranciaTempC,
                     double umbralProbHelada, int mesesSecosMax, double balanceMesSecoMm,
                     int aniosClimaAlta, double factorLluviaMin, int maxCandidatas, List<Regla> reglas) {

    public record Regla(String id, String tipo, String descripcion, String porque) {}
}
