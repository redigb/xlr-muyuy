package pe.muyuy.core.coordenada;

import io.quarkus.test.Mock;
import jakarta.enterprise.context.ApplicationScoped;
import pe.muyuy.core.data.RepositorioCalendarios;
import pe.muyuy.core.model.Calendario;
import pe.muyuy.core.model.Zona;

import java.util.OptionalInt;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Reemplaza a FuenteClimaHttp en las pruebas: nunca llama a NASA ni a Open-Meteo.
 * Devuelve el calendario real de la sierra (data/). Latitud 59.x simula que NASA no responde.
 */
@Mock
@ApplicationScoped
public class FuenteClimaFalsa implements FuenteClima {

    public static final double LAT_FALLA = 59.0;
    public static final AtomicInteger LLAMADAS = new AtomicInteger();

    private final RepositorioCalendarios calendarios;

    public FuenteClimaFalsa(RepositorioCalendarios calendarios) { this.calendarios = calendarios; }

    @Override
    public OptionalInt elevacion(double lat, double lon) { return OptionalInt.of(3200); }

    @Override
    public Calendario calendario(Zona zona, Integer elevacionM) {
        LLAMADAS.incrementAndGet();
        if (Math.floor(zona.lat()) == LAT_FALLA) throw new ClimaNoDisponible("simulado", null);
        Calendario sierra = calendarios.deZona("huanuco-sierra").orElseThrow();
        return new Calendario(zona, sierra.fuente(), sierra.anios(), sierra.calendario());
    }
}
