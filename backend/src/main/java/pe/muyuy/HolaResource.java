package pe.muyuy;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.openapi.annotations.Operation;

import java.util.Map;

/** "Hola" de verificacion del despliegue. Los endpoints reales viven en api/. */
@Path("/")
public class HolaResource {
    @GET
    @Operation(summary = "Server hello", description = "Quick deployment check (HTTPS and proxy). Links to the documentation.")
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, String> hola() {
        return Map.of("app", "muyuy", "estado", "ok", "docs", "/q/swagger-ui");
    }
}
