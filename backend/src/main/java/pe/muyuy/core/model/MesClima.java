package pe.muyuy.core.model;

import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "Typical climate of one month, summarized from 40 years of NASA POWER data. The basis of the agro-climatic calendar.")
public record MesClima(
        @Schema(description = "Month of the year, 1 = January … 12 = December") int mes,
        @Schema(description = "Probability of frost in that month (0 to 1). Decides which crops survive") double probHelada,
        @Schema(description = "Average monthly rainfall (mm)") double lluviaMm,
        @Schema(description = "Evapotranspiration: water lost by soil and plants in the month (mm)") double etMm,
        @Schema(description = "Rainfall − ET (mm). Negative = dry month: plants need more water than it rains") double balanceHidricoMm,
        @Schema(description = "Heat stress from 0 to 1 (0 = no excessively hot days)") double estresCalor,
        @Schema(description = "Average minimum temperature (°C). Below a crop's lethal temperature, the crop dies") double tMin,
        @Schema(description = "Average maximum temperature (°C)") double tMax) {

    public double tMedia() { return (tMin + tMax) / 2.0; }
}
