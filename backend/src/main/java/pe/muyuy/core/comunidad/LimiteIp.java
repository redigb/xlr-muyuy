package pe.muyuy.core.comunidad;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/** Límite simple en memoria: N peticiones por clave (IP) en una ventana de tiempo. */
public class LimiteIp {

    private record Ventana(Instant inicio, int cuenta) {}

    private final int maximo;
    private final Duration ventana;
    private final Map<String, Ventana> porClave = new ConcurrentHashMap<>();

    public LimiteIp(int maximo, Duration ventana) {
        this.maximo = maximo;
        this.ventana = ventana;
    }

    /** true si la petición se permite (y la cuenta). */
    public boolean permitir(String clave) { return permitir(clave, Instant.now()); }

    boolean permitir(String clave, Instant ahora) {
        Ventana v = porClave.compute(clave, (k, actual) ->
                actual == null || ahora.isAfter(actual.inicio().plus(ventana))
                        ? new Ventana(ahora, 1)
                        : new Ventana(actual.inicio(), actual.cuenta() + 1));
        if (porClave.size() > 10_000) porClave.clear();          // tope de memoria
        return v.cuenta() <= maximo;
    }
}
