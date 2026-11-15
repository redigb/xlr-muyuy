package pe.muyuy.api;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;
import pe.muyuy.core.red.ServicioRed;
import pe.muyuy.core.red.ServicioRed.RedPublica;

/** Datos de la página pública /red (SPECS_v2 §9.3). */
@Path("/api/red")
@Produces(MediaType.APPLICATION_JSON)
@Tag(name = "Network", description = "How the package spreads offline, phone to phone")
public class RedResource {

    private final ServicioRed red;

    public RedResource(ServicioRed red) { this.red = red; }

    @GET
    @Path("/publica")
    @Operation(summary = "Anonymous sharing network",
            description = "Nodes and COMPARTIO edges with random aliases that change on every request (no real ids), "
                    + "plus metrics (reach, max hops, % validated observations) and a 30-day daily series. "
                    + "Demo data is excluded.")
    public RedPublica publica() { return red.publica(); }
}
