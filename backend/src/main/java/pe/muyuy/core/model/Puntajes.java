package pe.muyuy.core.model;

/** Todos de 0 a 1 (riesgo: 1 = seguro). total = promedio de los 4. */
public record Puntajes(double agua, double suelo, double ingresos, double riesgo, double total) {

    public static Puntajes de(double agua, double suelo, double ingresos, double riesgo) {
        return new Puntajes(agua, suelo, ingresos, riesgo, (agua + suelo + ingresos + riesgo) / 4.0);
    }
}
