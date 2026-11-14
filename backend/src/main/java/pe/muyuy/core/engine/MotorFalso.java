package pe.muyuy.core.engine;

import jakarta.enterprise.context.ApplicationScoped;
import pe.muyuy.core.data.RepositorioCultivos;
import pe.muyuy.core.model.Calendario;
import pe.muyuy.core.model.Campania;
import pe.muyuy.core.model.Confianza;
import pe.muyuy.core.model.Cultivo;
import pe.muyuy.core.model.NivelConfianza;
import pe.muyuy.core.model.Puntajes;
import pe.muyuy.core.model.Rotacion;
import pe.muyuy.core.model.Zona;

import java.util.ArrayList;
import java.util.List;

/**
 * Motor de mentira con 3 rotaciones fijas para que la API y la app avancen ya.
 * Cuando exista MotorReal se anota con @Alternative @Priority(1) y reemplaza a este sin tocar la API.
 */
@ApplicationScoped
public class MotorFalso implements MotorRotaciones {

    private static final int MES_SIEMBRA = 10;
    private final RepositorioCultivos cultivos;

    public MotorFalso(RepositorioCultivos cultivos) { this.cultivos = cultivos; }

    @Override
    public List<Rotacion> recomendar(Zona zona, Calendario calendario) {
        String actual = zona.cultivoActual();
        List<String[]> secuencias = switch (zona.region()) {
            case "selva" -> List.of(new String[]{actual, "frijol", "yuca"}, new String[]{actual, "mucuna", "yuca"});
            case "valle" -> List.of(new String[]{actual, "arveja", "trigo"}, new String[]{actual, "frijol", "trigo"});
            default      -> List.of(new String[]{actual, "haba", "avena_forrajera"}, new String[]{actual, "tarwi", "cebada"});
        };
        var conf = new Confianza(NivelConfianza.alta, NivelConfianza.media, NivelConfianza.media, NivelConfianza.sin_datos);

        List<Rotacion> out = new ArrayList<>();
        out.add(new Rotacion("actual", "Rotacion actual", true,
                campanias(actual, actual, Cultivo.DESCANSO),
                Puntajes.de(0.6, 0.3, 0.7, 0.5), conf, "Confirma cuantos anios seguidos siembras " + actual + "."));
        out.add(new Rotacion("opcion-1", "Opcion 1", false, campanias(secuencias.get(0)),
                Puntajes.de(0.8, 0.9, 0.65, 0.8), conf, "Confirma si hay semilla y compradores en tu zona."));
        out.add(new Rotacion("opcion-2", "Opcion 2", false, campanias(secuencias.get(1)),
                Puntajes.de(0.85, 0.8, 0.6, 0.85), conf, "Confirma si hay semilla y compradores en tu zona."));
        return out;
    }

    private List<Campania> campanias(String... ids) {
        List<Campania> l = new ArrayList<>();
        for (int i = 0; i < ids.length; i++) {
            Cultivo c = cultivos.requerido(ids[i]);
            l.add(new Campania(i + 1, c.id(), c.nombre(), c.familia(), MES_SIEMBRA));
        }
        return l;
    }
}
