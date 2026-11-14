package pe.muyuy.core.model;

/** Un mes del calendario climatico (NASA POWER), mes = 1..12. */
public record MesClima(int mes, double probHelada, double lluviaMm, double etMm,
                       double balanceHidricoMm, double estresCalor, double tMin, double tMax) {

    public double tMedia() { return (tMin + tMax) / 2.0; }
}
