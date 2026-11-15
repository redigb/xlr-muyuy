package pe.muyuy.core.model;

import org.eclipse.microprofile.openapi.annotations.media.Schema;

import java.util.List;
import java.util.Map;

@Schema(description = "Agronomic profile of a crop (FAO ECOCROP + FAO-56 + MIDAGRI). This is what the engine decides with.")
public record Cultivo(
        @Schema(description = "Stable id", examples = "tarwi") String id,
        @Schema(description = "Display name") String nombre,
        @Schema(description = "Botanical family. Repeating it in consecutive seasons spreads pests, so the engine forbids it") String familia,
        @Schema(description = "true = staple field crop (cereal, tuber) that leads a rotation; legumes follow it") boolean principal,
        @Schema(description = "Ecological floors where it is traditionally grown") List<String> zonas,
        @Schema(description = "true = legume that restores nitrogen to the soil (raises the soil score)") boolean fijaNitrogeno,
        @Schema(description = "Frost tolerance: baja (low) | media (medium) | alta (high)") Nivel toleraHelada,
        @Schema(description = "Water need: baja (low) | media (medium) | alta (high)") Nivel agua,
        @Schema(description = "Months from sowing to harvest") int cicloMeses,
        @Schema(description = "Minimum optimal temperature (°C)") double tOptMin,
        @Schema(description = "Maximum optimal temperature (°C)") double tOptMax,
        @Schema(description = "Lethal temperature (°C): if any month of the cycle drops below it, the crop is not suitable") double ktmp,
        @Schema(description = "Minimum optimal annual rainfall (mm)") double lluviaOptMin,
        @Schema(description = "Maximum optimal annual rainfall (mm)") double lluviaOptMax,
        @Schema(description = "Relative market value from 0 to 1") double valorMercado,
        @Schema(description = "true = covers the soil or serves as forage (a good rotation closer)") boolean cobertura,
        @Schema(description = "true = deep roots (loosen the soil and reach deep water)") boolean raizProfunda,
        @Schema(description = "Traceability: source of each data point (climate, water, zone)") Map<String, String> fuente) {

    public static final String DESCANSO = "descanso";

    public boolean esDescanso() { return DESCANSO.equals(id); }
}
