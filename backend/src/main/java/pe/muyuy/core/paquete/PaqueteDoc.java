package pe.muyuy.core.paquete;

import org.eclipse.microprofile.openapi.annotations.media.Schema;
import pe.muyuy.core.model.Cultivo;
import pe.muyuy.core.model.MesClima;
import pe.muyuy.core.model.Rotacion;

import java.util.List;
import java.util.Map;

/**
 * Paquete regional, formato 2 (docs/SPECS_v2.md §3.2). El "sobre" lo agrega la app al compartir.
 * El hash cubre nucleo + extras; meta queda fuera.
 */
@Schema(description = "File the app downloads once and uses 100% offline. It can be shared phone to phone; "
        + "validity comes from the hash, not from who shared it.")
public record PaqueteDoc(Paquete paquete) {

    @Schema(description = "Sealed package content")
    public record Paquete(
            @Schema(description = "Metadata: version, hash and validity. Not covered by the hash") Meta meta,
            @Schema(description = "Decision data: climate, crops and rotations. Covered by the hash") Nucleo nucleo,
            @Schema(description = "Optional heavy parts (e.g. satellite image). Covered by the hash; empty for now") Map<String, Object> extras) {}

    @Schema(description = "Metadata to verify the package, compare versions and know whether data is still valid")
    public record Meta(
            @Schema(description = "File format version", examples = "2") int formato,
            @Schema(description = "zona_oficial (validated in Huánuco) | coordenada (any point, not validated)") String origen,
            @Schema(description = "Official zone id; null when the origin is a coordinate") String zona,
            @Schema(description = "0.5° grid cell when the origin is a coordinate; null for official zones") String celda,
            @Schema(description = "true = results checked in the field; when false the app shows a 'not locally validated' notice") boolean validadaLocalmente,
            @Schema(description = "Language of the explanations: es | en") String idioma,
            @Schema(description = "Increases only when content changes. When sharing offline, the newest version wins") int version,
            @Schema(description = "Generation timestamp (ISO-8601, UTC)") String generado,
            @Schema(description = "'sha256:' + SHA-256 of the canonical JSON of {extras, nucleo} (sorted keys, no whitespace, UTF-8). "
                    + "If the app computes a different value, it rejects the package") String hash,
            @Schema(description = "Validity of each section (calendario, condiciones, alertas) for the green/yellow/red indicator") Map<String, Seccion> secciones,
            @Schema(description = "Names of the parts present in extras") List<String> extras) {}

    @Schema(description = "Section validity: never show stale data as fresh")
    public record Seccion(
            @Schema(description = "Last update date (YYYY-MM-DD)") String actualizado,
            @Schema(description = "Valid until (YYYY-MM-DD). After that, the app dims the section and asks for a newer version") String validoHasta) {}

    @Schema(description = "Zone of the package")
    public record ZonaPaquete(
            @Schema(description = "Zone id") String id,
            @Schema(description = "Display name") String nombre,
            @Schema(description = "Latitude (degrees)") double lat,
            @Schema(description = "Longitude (degrees)") double lon,
            @Schema(description = "Elevation (m)") int elevacionM) {}

    @Schema(description = "Everything needed to decide offline")
    public record Nucleo(
            @Schema(description = "Zone of the package") ZonaPaquete zona,
            @Schema(description = "Climate source and period (e.g. NASA POWER 1985-2024, altitude-corrected)") String fuenteClima,
            @Schema(description = "Sowing month of each season (10 = October, start of the rainy season in the Andes)") int inicioSiembraMes,
            @Schema(description = "12 months of typical climate: the calendar the farmer sees") List<MesClima> calendario,
            @Schema(description = "Recent conditions vs. normal (e.g. last 30 days of rain). Empty for now") Map<String, Object> condiciones,
            @Schema(description = "Profiles of the crops used in the rotations") List<Cultivo> cultivos,
            @Schema(description = "ALL candidate rotations + the traditional practice. The app filters and ranks them") List<Rotacion> rotaciones,
            @Schema(description = "Events confirmed by the community and NASA data in the last 7 days") List<Alerta> alertasComunidad) {}

    @Schema(description = "Event validated by the community (NASA climate + neighbor consensus) in the last 7 days")
    public record Alerta(
            @Schema(description = "helada (frost) | sequia (drought) | lluvia_fuerte (heavy rain) | granizo (hail) | plaga (pest) | otro (other)") String tipo,
            @Schema(description = "Event date (YYYY-MM-DD)") String fecha,
            @Schema(description = "Number of distinct devices that reported it") int confirmaciones) {}
}
