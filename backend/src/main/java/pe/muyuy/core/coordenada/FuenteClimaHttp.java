package pe.muyuy.core.coordenada;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;
import pe.muyuy.core.model.Calendario;
import pe.muyuy.core.model.MesClima;
import pe.muyuy.core.model.Zona;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Arrays;
import java.util.Locale;
import java.util.OptionalInt;

/** Implementación real: Open-Meteo Elevation API (sin clave) + pipeline-api interno (FastAPI). */
@ApplicationScoped
public class FuenteClimaHttp implements FuenteClima {

    private static final Logger LOG = Logger.getLogger(FuenteClimaHttp.class);

    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();
    private final ObjectMapper mapper;
    private final String pipelineUrl;
    private final String elevacionUrl;
    private final Duration timeoutCalendario;

    public FuenteClimaHttp(ObjectMapper mapper,
                           @ConfigProperty(name = "muyuy.coordenada.pipeline-url") String pipelineUrl,
                           @ConfigProperty(name = "muyuy.coordenada.elevacion-url") String elevacionUrl,
                           @ConfigProperty(name = "muyuy.coordenada.timeout-segundos", defaultValue = "25") int timeout) {
        this.mapper = mapper;
        this.pipelineUrl = pipelineUrl.replaceAll("/$", "");
        this.elevacionUrl = elevacionUrl;
        this.timeoutCalendario = Duration.ofSeconds(timeout);
    }

    @Override
    public OptionalInt elevacion(double lat, double lon) {
        try {
            JsonNode r = get(elevacionUrl + "?latitude=" + fmt(lat) + "&longitude=" + fmt(lon), Duration.ofSeconds(5));
            JsonNode e = r.path("elevation").path(0);
            return e.isNumber() ? OptionalInt.of((int) Math.round(e.asDouble())) : OptionalInt.empty();
        } catch (Exception e) {
            LOG.warn("Open-Meteo no respondió; calendario sin corrección por altitud", e);
            return OptionalInt.empty();
        }
    }

    @Override
    public Calendario calendario(Zona zona, Integer elevacionM) {
        String url = pipelineUrl + "/calendario?lat=" + fmt(zona.lat()) + "&lon=" + fmt(zona.lon())
                + (elevacionM == null ? "" : "&elev=" + elevacionM);
        try {
            JsonNode r = get(url, timeoutCalendario);
            MesClima[] meses = mapper.treeToValue(r.path("calendario"), MesClima[].class);
            if (meses == null || meses.length != 12) throw new IllegalStateException("calendario incompleto");
            return new Calendario(zona, r.path("fuente").asText(), r.path("anios").asInt(), Arrays.asList(meses));
        } catch (Exception e) {
            throw new ClimaNoDisponible("pipeline-api no devolvió el calendario de " + zona.id(), e);
        }
    }

    private JsonNode get(String url, Duration timeout) throws Exception {
        HttpRequest req = HttpRequest.newBuilder(URI.create(url)).timeout(timeout)
                .header("Accept", "application/json").GET().build();
        HttpResponse<String> resp = http.send(req, HttpResponse.BodyHandlers.ofString());
        if (resp.statusCode() != 200) throw new IllegalStateException(url + " respondió " + resp.statusCode());
        return mapper.readTree(resp.body());
    }

    private static String fmt(double v) { return String.format(Locale.ROOT, "%.4f", v); }
}
