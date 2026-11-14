package pe.muyuy.core.model;

import org.eclipse.microprofile.openapi.annotations.media.Schema;

import java.util.List;

@Schema(description = "Candidate 3-season crop rotation (one crop per year). Produced by a deterministic engine from NASA data; "
        + "AI only explains it. The app filters by cultivo_inicial and ranks by scores, fully offline.")
public record Rotacion(
        @Schema(description = "Stable id = crop sequence joined by dashes; prefixed 'comun-' for the traditional practice",
                examples = "papa-tarwi-avena_forrajera") String id,
        @Schema(description = "First crop; the app only shows rotations starting with what the farmer grows today") String cultivoInicial,
        @Schema(description = "Crop ids per season (years 1, 2 and 3). Details of each crop in nucleo.cultivos") List<String> secuencia,
        @Schema(description = "Per-factor scores from 0 to 1") Puntajes puntajes,
        @Schema(description = "Per-factor confidence based on data quality") Confianza confianza,
        @Schema(description = "Why it is proposed, in plain language (Groq, or a template fallback)") String explicacion,
        @Schema(description = "What to confirm with an agronomist or neighbor before deciding; targets the weakest factor") String validarConExperto,
        @Schema(description = "true = the zone's traditional rotation, shown as 'your current rotation' for comparison") boolean esPracticaComun) {

    public Rotacion conExplicacion(String texto) {
        return new Rotacion(id, cultivoInicial, secuencia, puntajes, confianza, texto, validarConExperto, esPracticaComun);
    }
}
