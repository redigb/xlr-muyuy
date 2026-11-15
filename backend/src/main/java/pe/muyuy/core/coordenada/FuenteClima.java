package pe.muyuy.core.coordenada;

import pe.muyuy.core.model.Calendario;
import pe.muyuy.core.model.Zona;

import java.util.OptionalInt;

/** Clima de cualquier punto: elevación (Open-Meteo) + calendario NASA POWER (pipeline-api). */
public interface FuenteClima {

    /** Elevación en metros; vacío si el servicio falla (se calcula sin corrección por altitud). */
    OptionalInt elevacion(double lat, double lon);

    /** Calendario de 12 meses del punto. Lanza {@link ClimaNoDisponible} si NASA o pipeline-api fallan. */
    Calendario calendario(Zona zona, Integer elevacionM);

    class ClimaNoDisponible extends RuntimeException {
        public ClimaNoDisponible(String mensaje, Throwable causa) { super(mensaje, causa); }
    }
}
