package pe.muyuy.core.coordenada;

import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import pe.muyuy.core.engine.MotorReal;
import pe.muyuy.core.model.Calendario;
import pe.muyuy.core.model.Zona;
import pe.muyuy.core.paquete.ServicioPaquetes;
import pe.muyuy.core.paquete.ServicioPaquetes.Sellado;

import java.util.List;
import java.util.Locale;
import java.util.OptionalInt;

/**
 * Paquete bajo demanda para cualquier punto (SPECS_v2 §11.1):
 * validar → celda 0.5° → caché → elevación → calendario NASA → motor → Groq → sellar.
 * Solo se usa la celda (~50 km): la ubicación exacta nunca se guarda (§15).
 */
@ApplicationScoped
public class ServicioCoordenadas {

    public static final double PASO_CELDA = 0.5;

    private final ServicioPaquetes paquetes;
    private final FuenteClima clima;
    private final int cacheDias;

    public ServicioCoordenadas(ServicioPaquetes paquetes, FuenteClima clima,
                               @ConfigProperty(name = "muyuy.coordenada.cache-dias", defaultValue = "30") int cacheDias) {
        this.paquetes = paquetes;
        this.clima = clima;
        this.cacheDias = cacheDias;
    }

    /** @throws IllegalArgumentException coordenada fuera de rango · {@link FuenteClima.ClimaNoDisponible} */
    public Sellado paquete(double lat, double lon, String lang) {
        if (Double.isNaN(lat) || lat < -60 || lat > 60) throw new IllegalArgumentException("lat must be between -60 and 60");
        if (Double.isNaN(lon) || lon < -180 || lon > 180) throw new IllegalArgumentException("lon must be between -180 and 180");
        String idioma = ServicioPaquetes.idioma(lang);
        double cLat = redondear(lat), cLon = redondear(lon);
        String celda = celda(cLat, cLon);

        var reciente = paquetes.coordenadaReciente(celda, idioma, cacheDias);
        if (reciente.isPresent()) return reciente.get();

        OptionalInt elev = clima.elevacion(cLat, cLon);
        Zona zona = zona(celda, cLat, cLon, elev.orElse(0), idioma);
        Calendario cal = clima.calendario(zona, elev.isPresent() ? elev.getAsInt() : null);
        return paquetes.coordenada(celda, idioma, zona, cal);
    }

    static double redondear(double v) { return Math.round(v / PASO_CELDA) * PASO_CELDA; }

    /** "-9.5_-76.0": misma malla que NASA POWER (0.5°). */
    static String celda(double lat, double lon) {
        return String.format(Locale.ROOT, "%.1f_%.1f", lat + 0.0, lon + 0.0);   // + 0.0 evita "-0.0"
    }

    private static Zona zona(String celda, double lat, double lon, int elev, String idioma) {
        String nombre = String.format(Locale.ROOT, "en".equals(idioma) ? "Area near %.1f°, %.1f°" : "Zona cerca de %.1f°, %.1f°",
                lat, lon);
        return new Zona("celda_" + celda, nombre, MotorReal.REGION_COORDENADA, lat, lon, elev, false, List.of(), null);
    }
}
