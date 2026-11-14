package pe.muyuy.core.model;

import org.eclipse.microprofile.openapi.annotations.media.Schema;

@Schema(description = "How much to trust each factor, based on the quality of the underlying data. "
        + "Honesty about uncertainty: the app shows it next to each score.")
public record Confianza(
        @Schema(description = "alta (high) with 30+ years of NASA data; media (medium) with fewer years or when the zone is not locally validated") NivelConfianza clima,
        @Schema(description = "alta when rainfall and evapotranspiration data exist for rain-fed farming") NivelConfianza agua,
        @Schema(description = "media: no lab soil analysis in the MVP") NivelConfianza suelo,
        @Schema(description = "sin_datos (no data) unless a local price is loaded (MIDAGRI)") NivelConfianza mercado) {}
