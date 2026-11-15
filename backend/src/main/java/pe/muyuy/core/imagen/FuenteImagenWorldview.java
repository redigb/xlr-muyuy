package pe.muyuy.core.imagen;

import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;
import pe.muyuy.core.model.Zona;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * NASA Worldview Snapshots (sin clave). Fecha y capa FIJAS por configuración: la misma foto
 * da el mismo hash, así el paquete no cambia de versión solo por la imagen.
 */
@ApplicationScoped
public class FuenteImagenWorldview implements FuenteImagen {

    private static final Logger LOG = Logger.getLogger(FuenteImagenWorldview.class);
    private static final int MAX_BYTES = 200_000;

    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5))
            .followRedirects(HttpClient.Redirect.NORMAL).build();
    private final Map<String, byte[]> cache = new ConcurrentHashMap<>();
    private final boolean activa;
    private final String url;
    private final String capa;
    private final String fecha;
    private final double radioGrados;
    private final int pixeles;

    public FuenteImagenWorldview(
            @ConfigProperty(name = "muyuy.imagen.activa", defaultValue = "true") boolean activa,
            @ConfigProperty(name = "muyuy.imagen.url") String url,
            @ConfigProperty(name = "muyuy.imagen.capa") String capa,
            @ConfigProperty(name = "muyuy.imagen.fecha") String fecha,
            @ConfigProperty(name = "muyuy.imagen.radio-grados", defaultValue = "0.3") double radioGrados,
            @ConfigProperty(name = "muyuy.imagen.pixeles", defaultValue = "600") int pixeles) {
        this.activa = activa;
        this.url = url;
        this.capa = capa;
        this.fecha = fecha;
        this.radioGrados = radioGrados;
        this.pixeles = pixeles;
    }

    @Override
    public Optional<byte[]> jpeg(Zona zona) {
        if (!activa) return Optional.empty();
        byte[] previa = cache.get(zona.id());
        if (previa != null) return Optional.of(previa);
        try {
            var r = http.send(HttpRequest.newBuilder(URI.create(urlPara(zona.lat(), zona.lon())))
                    .timeout(Duration.ofSeconds(15)).GET().build(), HttpResponse.BodyHandlers.ofByteArray());
            byte[] b = r.body();
            if (r.statusCode() != 200 || !esJpeg(b) || b.length > MAX_BYTES) {
                LOG.warnf("Worldview no dio un JPEG válido para %s (HTTP %d, %d bytes)", zona.id(), r.statusCode(), b.length);
                return Optional.empty();
            }
            cache.put(zona.id(), b);
            return Optional.of(b);
        } catch (Exception e) {
            if (e instanceof InterruptedException) Thread.currentThread().interrupt();
            LOG.warn("Worldview no respondió para " + zona.id() + "; paquete sin imagen", e);
            return Optional.empty();
        }
    }

    /** BBOX en EPSG:4326 = sur,oeste,norte,este. */
    String urlPara(double lat, double lon) {
        String bbox = String.format(Locale.ROOT, "%.4f,%.4f,%.4f,%.4f",
                lat - radioGrados, lon - radioGrados, lat + radioGrados, lon + radioGrados);
        return url + "?REQUEST=GetSnapshot&LAYERS=" + capa + "&CRS=EPSG:4326&TIME=" + fecha
                + "&WRAP=DAY&BBOX=" + bbox + "&FORMAT=image/jpeg&WIDTH=" + pixeles + "&HEIGHT=" + pixeles;
    }

    static boolean esJpeg(byte[] b) {
        return b != null && b.length > 3 && (b[0] & 0xFF) == 0xFF && (b[1] & 0xFF) == 0xD8;
    }
}
