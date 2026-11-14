package pe.muyuy.core.model;

import org.eclipse.microprofile.openapi.annotations.media.Schema;

import java.util.List;

@Schema(description = "Official farming zone with a precomputed package (field-validated in Huánuco, Peru).")
public record Zona(
        @Schema(description = "Stable id, used in /api/paquete/{zona}", examples = "huanuco-sierra") String id,
        @Schema(description = "Display name for the farmer") String nombre,
        @Schema(description = "Ecological floor: sierra (highlands) | valle (valley) | selva (rainforest) | global. Decides which crops are considered", examples = "sierra") String region,
        @Schema(description = "Latitude of the representative point (degrees)") double lat,
        @Schema(description = "Longitude of the representative point (degrees)") double lon,
        @Schema(description = "Elevation in meters; used to correct NASA temperatures for altitude") int elevacionM,
        @Schema(description = "true if the zone is irrigated; in rain-fed farming, rainfall limits which crops are suitable") boolean riego,
        @Schema(description = "Crops the farmer can pick as 'what I grow today'; every rotation starts with one of them") List<String> cultivosIniciales,
        @Schema(description = "Traditional rotation of the zone, shown as 'your current rotation' for comparison; null if not applicable") List<String> practicaComun) {}
