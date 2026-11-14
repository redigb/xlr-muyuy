package pe.muyuy.core.model;

/** Todos de 0 a 1 (riesgo: 1 = seguro), redondeados a 2 decimales para un hash estable. total = promedio. */
public record Puntajes(double agua, double suelo, double ingresos, double riesgo, double total) {

    public static Puntajes de(double agua, double suelo, double ingresos, double riesgo) {
        double a = r(agua), s = r(suelo), i = r(ingresos), g = r(riesgo);
        return new Puntajes(a, s, i, g, r((a + s + i + g) / 4.0));
    }

    private static double r(double v) { return Math.round(Math.max(0, Math.min(1, v)) * 100) / 100.0; }
}
