package pe.muyuy.core.model;

import java.util.List;
import java.util.Map;

/** Una fila de data/cultivos.json. ktmp = temperatura letal (°C); lluvia_opt_* en mm/año (ECOCROP). */
public record Cultivo(String id, String nombre, String familia, List<String> zonas,
                      boolean fijaNitrogeno, Nivel toleraHelada, Nivel agua, int cicloMeses,
                      double tOptMin, double tOptMax, double ktmp,
                      double lluviaOptMin, double lluviaOptMax, double valorMercado,
                      boolean cobertura, boolean raizProfunda, Map<String, String> fuente) {

    public static final String DESCANSO = "descanso";

    public boolean esDescanso() { return DESCANSO.equals(id); }
}
