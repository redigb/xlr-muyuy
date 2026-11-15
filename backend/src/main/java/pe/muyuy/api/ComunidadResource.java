package pe.muyuy.api;

import io.vertx.core.http.HttpServerRequest;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.HeaderParam;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;
import pe.muyuy.api.ApiResource.ErrorApi;
import pe.muyuy.core.comunidad.LimiteIp;
import pe.muyuy.core.comunidad.ServicioComunidad;
import pe.muyuy.core.comunidad.ServicioComunidad.Registro;
import pe.muyuy.core.comunidad.ServicioComunidad.SyncIn;
import pe.muyuy.core.comunidad.ServicioComunidad.SyncOut;

import java.time.Duration;

/** Escritura de la comunidad (SPECS_v2 §8 y §11): leer es público, escribir exige token de dispositivo. */
@Path("/api")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@Tag(name = "Community", description = "What farmers observe in the field flows back to the system when there is signal")
public class ComunidadResource {

    @Schema(description = "Optional registration data. No personal data")
    public record RegistroIn(
            @Schema(description = "true if the registration comes from the web demo for judges") Boolean demo,
            @Schema(description = "Anonymous id the app generated on first use ('disp-<uuid>'); used offline in package "
                    + "envelopes and COMPARTIO connections. Optional", examples = "disp-3f2c9a1e-8b7d-4c2a-9e1f-5a6b7c8d9e0f") String idLocal) {}

    private final ServicioComunidad comunidad;
    private final LimiteIp limiteRegistros;

    public ComunidadResource(ServicioComunidad comunidad,
                             @ConfigProperty(name = "muyuy.limites.dispositivos-por-hora", defaultValue = "30") int porHora) {
        this.comunidad = comunidad;
        this.limiteRegistros = new LimiteIp(porHora, Duration.ofHours(1));
    }

    @POST
    @Path("/dispositivos")
    @Operation(summary = "Register an anonymous device",
            description = "Called ONCE, the first time the app has signal. Asks for no personal data: returns an "
                    + "id and a token that the app stores and sends to /api/sync. The server only stores the token hash. "
                    + "Registrations are limited per IP and hour (anti-bot). The web demo sends {\"demo\": true}.")
    @APIResponse(responseCode = "201", content = @Content(schema = @Schema(implementation = Registro.class)))
    @APIResponse(responseCode = "429", description = "Too many registrations from this IP")
    public Response registrar(RegistroIn in, @Context HttpServerRequest req) {
        String ip = req.remoteAddress() == null ? "desconocida" : req.remoteAddress().host();
        if (!limiteRegistros.permitir(ip)) {
            return Response.status(429).entity(new ErrorApi("Too many registrations from this network. Try again later.")).build();
        }
        boolean demo = in != null && Boolean.TRUE.equals(in.demo());
        return Response.status(Response.Status.CREATED)
                .entity(comunidad.registrar(demo, in == null ? null : in.idLocal())).build();
    }

    @POST
    @Path("/sync")
    @Operation(summary = "Sync observations and connections saved offline",
            description = "The app sends what it stored offline. Idempotent by id_local: resending never duplicates. "
                    + "Each observation gets an automatic score from 0 to 100 (up to 55 for matching NASA climate "
                    + "and up to 45 for consensus with other devices in the zone within ±3 days): "
                    + "≥ 70 validada (validated), 40–69 pendiente (pending), < 40 sospechosa (suspicious). Validated ones become "
                    + "alerts in the zone's next package. Demo data never counts. Header: Authorization: Bearer <token>.")
    @APIResponse(responseCode = "200", content = @Content(schema = @Schema(implementation = SyncOut.class)))
    @APIResponse(responseCode = "401", description = "Missing or invalid token, or blocked device")
    public Response sync(@HeaderParam("Authorization") String autorizacion, SyncIn in) {
        String token = autorizacion != null && autorizacion.startsWith("Bearer ") ? autorizacion.substring(7).trim() : null;
        return comunidad.autenticar(token)
                .map(d -> Response.ok(comunidad.sincronizar(d, in)).build())
                .orElseGet(() -> Response.status(Response.Status.UNAUTHORIZED)
                        .entity(new ErrorApi("Invalid device token. Register the device at /api/dispositivos")).build());
    }
}
