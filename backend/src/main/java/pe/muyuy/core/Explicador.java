package pe.muyuy.core;

import pe.muyuy.core.model.Calendario;
import pe.muyuy.core.model.Rotacion;
import pe.muyuy.core.model.Zona;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Redacta por qué se propone una rotación. La IA explica, no decide. idioma = es | en. */
public interface Explicador {

    String explicar(Rotacion rotacion, Zona zona, Calendario calendario, String idioma);

    /** Lote: id de rotación → explicación. Puede devolver menos entradas; quien llama completa con plantilla. */
    default Map<String, String> explicarTodas(List<Rotacion> rotaciones, Zona zona, Calendario calendario, String idioma) {
        Map<String, String> out = new LinkedHashMap<>();
        rotaciones.forEach(r -> out.put(r.id(), explicar(r, zona, calendario, idioma)));
        return out;
    }
}
