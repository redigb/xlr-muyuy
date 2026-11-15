package pe.muyuy.core.coordenada;

import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import pe.muyuy.core.data.RepositorioZonas;
import pe.muyuy.core.engine.MotorReal;
import pe.muyuy.core.model.Calendario;
import pe.muyuy.core.model.Zona;
import pe.muyuy.core.paquete.ServicioPaquetes;
import pe.muyuy.core.paquete.ServicioPaquetes.Sellado;

import java.util.List;
import java.util.Comparator;
import java.util.Locale;
import java.util.Optional;
import java.util.OptionalInt;

/**
 * Paquete bajo demanda para cualquier punto (SPECS_v2 §11.1):
 * validar → celda 0.5° → caché → elevación → calendario NASA → motor → Groq → sellar.
 * Solo se usa la celda (~50 km): la ubicación exacta nunca se guarda (§15).
 * Si el punto está cerca de una zona oficial (radio-zona-km), se entrega el paquete de esa zona:
 * validado localmente, con sus cultivos y su práctica común.
 */
@ApplicationScoped
public class ServicioCoordenadas {

    public static final double PASO_CELDA = 0.5;

    private static final double RADIO_TIERRA_KM = 6371;

    private final ServicioPaquetes paquetes;
    private final FuenteClima clima;
    private final RepositorioZonas zonas;
    private final int cacheDias;
    private final double radioZonaKm;

    public ServicioCoordenadas(ServicioPaquetes paquetes, FuenteClima clima, RepositorioZonas zonas,
                               @ConfigProperty(name = "muyuy.coordenada.cache-dias", defaultValue = "30") int cacheDias,
                               @ConfigProperty(name = "muyuy.coordenada.radio-zona-km", defaultValue = "30") double radioZonaKm) {
        this.paquetes = paquetes;
        this.clima = clima;
        this.zonas = zonas;
        this.cacheDias = cacheDias;
        this.radioZonaKm = radioZonaKm;
    }

    /** @throws IllegalArgumentException coordenada fuera de rango · {@link FuenteClima.ClimaNoDisponible} */
    public Sellado paquete(double lat, double lon, String lang) { return paquete(lat, lon, lang, false); }

    /** riego = true: el agricultor riega, la lluvia no descarta cultivos (otra variante en caché). */
    public Sellado paquete(double lat, double lon, String lang, boolean riego) {
        if (Double.isNaN(lat) || lat < -60 || lat > 60) throw new IllegalArgumentException("lat must be between -60 and 60");
        if (Double.isNaN(lon) || lon < -180 || lon > 180) throw new IllegalArgumentException("lon must be between -180 and 180");
        String idioma = ServicioPaquetes.idioma(lang);
        Optional<Sellado> oficial = zonaOficialCercana(lat, lon).flatMap(z -> paquetes.obtener(z.id(), idioma));
        if (oficial.isPresent()) return oficial.get();
        double cLat = redondear(lat), cLon = redondear(lon);
        String celda = celda(cLat, cLon);

        var reciente = paquetes.coordenadaReciente(celda, idioma, riego, cacheDias);
        if (reciente.isPresent()) return reciente.get();

        OptionalInt elev = clima.elevacion(cLat, cLon);
        Zona zona = zona(celda, cLat, cLon, elev.orElse(0), idioma, riego);
        Calendario cal = clima.calendario(zona, elev.isPresent() ? elev.getAsInt() : null);
        return paquetes.coordenada(celda, idioma, zona, cal);
    }

    /** Zona oficial (no "global") más cercana dentro del radio. El punto exacto solo se usa aquí, en memoria. */
    Optional<Zona> zonaOficialCercana(double lat, double lon) {
        return zonas.todas().stream()
                .filter(z -> !"global".equals(z.region()))
                .filter(z -> distanciaKm(lat, lon, z.lat(), z.lon()) <= radioZonaKm)
                .min(Comparator.comparingDouble(z -> distanciaKm(lat, lon, z.lat(), z.lon())));
    }

    /** Haversine. */
    static double distanciaKm(double lat1, double lon1, double lat2, double lon2) {
        double dLat = Math.toRadians(lat2 - lat1), dLon = Math.toRadians(lon2 - lon1);
        double a = Math.pow(Math.sin(dLat / 2), 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) * Math.pow(Math.sin(dLon / 2), 2);
        return 2 * RADIO_TIERRA_KM * Math.asin(Math.sqrt(a));
    }

    static double redondear(double v) { return Math.round(v / PASO_CELDA) * PASO_CELDA; }

    /** "-9.5_-76.0": misma malla que NASA POWER (0.5°). */
    static String celda(double lat, double lon) {
        return String.format(Locale.ROOT, "%.1f_%.1f", lat + 0.0, lon + 0.0);   // + 0.0 evita "-0.0"
    }

    private static Zona zona(String celda, double lat, double lon, int elev, String idioma, boolean riego) {
        String nombre = String.format(Locale.ROOT, "en".equals(idioma) ? "Area near %.1f°, %.1f°" : "Zona cerca de %.1f°, %.1f°",
                lat, lon);
        return new Zona("celda_" + celda, nombre, MotorReal.REGION_COORDENADA, lat, lon, elev, riego, List.of(), null);
    }
}
