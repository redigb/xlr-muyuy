package pe.muyuy.core.model;

import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "How good the rotation is on each factor, from 0 (poor) to 1 (excellent). "
        + "The app weights them by the farmer's priorities to rank the options.")
public record Puntajes(
        @Schema(description = "Water use: high when crops need little water and their cycles avoid dry months") double agua,
        @Schema(description = "Soil health: rises with legumes (nitrogen fixers), 3 different families and ending with cover or forage") double suelo,
        @Schema(description = "Expected income: average market value of the crops (0.5 = no data)") double ingresos,
        @Schema(description = "Safety against frost and drought according to NASA climate. 1 = very safe") double riesgo,
        @Schema(description = "Average of the 4 factors; default ranking when the farmer sets no priorities") double total) {

    public static Puntajes de(double agua, double suelo, double ingresos, double riesgo) {
        double a = r(agua), s = r(suelo), i = r(ingresos), g = r(riesgo);
        return new Puntajes(a, s, i, g, r((a + s + i + g) / 4.0));
    }

    private static double r(double v) { return Math.round(Math.max(0, Math.min(1, v)) * 100) / 100.0; }
}
