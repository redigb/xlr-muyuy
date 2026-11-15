package pe.muyuy.api;

import io.vertx.core.http.HttpServerRequest;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.QueryParam;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.parameters.Parameter;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;
import pe.muyuy.core.comunidad.LimiteIp;
import pe.muyuy.core.coordenada.FuenteClima.ClimaNoDisponible;
import pe.muyuy.core.coordenada.ServicioCoordenadas;
import pe.muyuy.core.data.RepositorioZonas;
import pe.muyuy.core.model.Zona;
import pe.muyuy.core.paquete.PaqueteDoc;
import pe.muyuy.core.paquete.ServicioPaquetes;
import pe.muyuy.core.paquete.ServicioPaquetes.Sellado;

import java.time.Duration;
import java.util.List;
import java.util.Map;

/** API pública de lectura (SPECS_v2 §11). Sin autenticación: los paquetes son datos públicos. */
@Path("/api")
@Produces(MediaType.APPLICATION_JSON)
@Tag(name = "Packages", description = "Regional packages the app downloads once and uses offline")
public class ApiResource {

    @Schema(description = "Current version; the app downloads the package only if it is newer than the installed one")
    public record VersionPaquete(
            @Schema(description = "Package version; increases only when content changes") int version,
            @Schema(description = "Content hash; lets the app compare without downloading") String hash) {}

    @Schema(description = "Error with a clear message to show or log")
    public record ErrorApi(@Schema(description = "What happened and what to do") String error) {}

    private final RepositorioZonas zonas;
    private final ServicioPaquetes paquetes;
    private final ServicioCoordenadas coordenadas;
    private final LimiteIp limiteCoordenadas;

    public ApiResource(RepositorioZonas zonas, ServicioPaquetes paquetes, ServicioCoordenadas coordenadas,
                       @ConfigProperty(name = "muyuy.limites.coordenadas-por-hora", defaultValue = "20") int porHora) {
        this.zonas = zonas;
        this.paquetes = paquetes;
        this.coordenadas = coordenadas;
        this.limiteCoordenadas = new LimiteIp(porHora, Duration.ofHours(1));
    }

    @GET
    @Path("/salud")
    @Operation(summary = "Is the server alive?",
            description = "The app uses it to check for a usable connection before syncing. Returns {\"ok\": true}.")
    public Map<String, Boolean> salud() {
        return Map.of("ok", true);
    }

    @GET
    @Path("/zonas")
    @Operation(summary = "Available official zones",
            description = "Lists the zones with a precomputed package so the farmer can pick theirs. "
                    + "cultivos_iniciales are the crops they can mark as 'what I grow today'.")
    public List<Zona> zonas() {
        return zonas.todas();
    }

    @GET
    @Path("/paquete/{zona}/version")
    @Operation(summary = "Current package version of a zone",
            description = "Lightweight check: the app compares it with the installed version and downloads the full "
                    + "package only if this one is newer ('newest wins').")
    @APIResponse(responseCode = "200", content = @Content(schema = @Schema(implementation = VersionPaquete.class)))
    @APIResponse(responseCode = "404", description = "Unknown zone",
            content = @Content(schema = @Schema(implementation = ErrorApi.class)))
    public Response version(@PathParam("zona") String zona,
                            @Parameter(description = "Language of the explanations: es (default) | en") @QueryParam("lang") String lang) {
        return paquetes.obtener(zona, ServicioPaquetes.idioma(lang))
                .map(s -> Response.ok(new VersionPaquete(s.version(), s.hash())).build())
                .orElseGet(() -> noExiste(zona));
    }

    @GET
    @Path("/paquete/{zona}")
    @Operation(summary = "Full package of an official zone",
            description = "Everything the app needs to work offline: NASA climate calendar, "
                    + "crops and ALL candidate rotations with scores, confidence and explanation. "
                    + "The app filters by the current crop and ranks by the farmer's priorities. "
                    + "Verification: meta.hash = 'sha256:' + SHA-256 of the canonical JSON of {extras, nucleo} "
                    + "(keys sorted alphabetically at every level, no whitespace, UTF-8).")
    @APIResponse(responseCode = "200", content = @Content(schema = @Schema(implementation = PaqueteDoc.class)))
    @APIResponse(responseCode = "404", description = "Unknown zone",
            content = @Content(schema = @Schema(implementation = ErrorApi.class)))
    public Response paquete(@PathParam("zona") String zona,
                            @Parameter(description = "Language of the explanations: es (default) | en") @QueryParam("lang") String lang) {
        return paquetes.obtener(zona, ServicioPaquetes.idioma(lang)).map(this::servir).orElseGet(() -> noExiste(zona));
    }

    @GET
    @Path("/paquete/coordenada")
    @Operation(summary = "On-demand package for any location",
            description = "Same calculation as the official zones for any point: NASA POWER 1985-2024 for the 0.5° grid "
                    + "cell, altitude-corrected with Open-Meteo elevation, sowing month computed from the rainy season, "
                    + "and candidate rotations explained in the requested language. Not field-validated: "
                    + "meta.validada_localmente = false and confidence is at most 'media'. Only the ~50 km cell is used "
                    + "and cached (30 days); the exact location is never stored. Can take 5-20 s the first time per cell. "
                    + "Limited per IP. On 504 the app falls back to the bundled Huánuco package.")
    @APIResponse(responseCode = "200", content = @Content(schema = @Schema(implementation = PaqueteDoc.class)))
    @APIResponse(responseCode = "400", description = "lat/lon out of range",
            content = @Content(schema = @Schema(implementation = ErrorApi.class)))
    @APIResponse(responseCode = "429", description = "Too many requests from this IP")
    @APIResponse(responseCode = "504", description = "NASA data not available in time")
    public Response coordenada(@Parameter(description = "Latitude, -60 to 60", required = true) @QueryParam("lat") Double lat,
                               @Parameter(description = "Longitude, -180 to 180", required = true) @QueryParam("lon") Double lon,
                               @Parameter(description = "Language of the explanations: es | en (default)") @QueryParam("lang") String lang,
                               @Context HttpServerRequest req) {
        if (lat == null || lon == null) return error(400, "lat and lon are required");
        String ip = req == null || req.remoteAddress() == null ? "desconocida" : req.remoteAddress().host();
        if (!limiteCoordenadas.permitir(ip)) return error(429, "Too many location requests from this network. Try again later.");
        try {
            return servir(coordenadas.paquete(lat, lon, lang == null ? ServicioPaquetes.EN : lang));
        } catch (IllegalArgumentException e) {
            return error(400, e.getMessage());
        } catch (ClimaNoDisponible e) {
            return error(504, "NASA climate data is not available right now. Try again later.");
        }
    }

    private static Response error(int status, String mensaje) {
        return Response.status(status).entity(new ErrorApi(mensaje)).build();
    }

    private Response servir(Sellado s) {
        paquetes.registrarDescarga(s);
        return Response.ok(s.contenido(), MediaType.APPLICATION_JSON).build();   // texto exacto que se selló
    }

    private static Response noExiste(String zona) {
        return Response.status(Response.Status.NOT_FOUND)
                .entity(new ErrorApi("Unknown zone: " + zona + ". See /api/zonas")).build();
    }
}
