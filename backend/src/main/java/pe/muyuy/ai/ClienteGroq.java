package pe.muyuy.ai;

import com.fasterxml.jackson.annotation.JsonInclude;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.HeaderParam;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

import java.util.List;
import java.util.Map;

/** Groq (API compatible con OpenAI). URL y timeouts en application.yml: quarkus.rest-client.groq. */
@RegisterRestClient(configKey = "groq")
@Path("/v1/chat/completions")
public interface ClienteGroq {

    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    Respuesta chat(@HeaderParam("Authorization") String autorizacion, Peticion peticion);

    record Mensaje(String role, String content) {}

    /** reasoning_effort: low = piensa poco y deja tokens para el JSON (ver scripts/eval_groq.py). null = no se envía. */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    record Peticion(String model, List<Mensaje> messages, double temperature, int maxTokens,
                    Map<String, String> responseFormat, String reasoningEffort) {}

    record Respuesta(List<Opcion> choices) {
        public record Opcion(Mensaje message) {}

        public String texto() {
            return choices == null || choices.isEmpty() || choices.get(0).message() == null
                    ? "" : choices.get(0).message().content();
        }
    }
}
