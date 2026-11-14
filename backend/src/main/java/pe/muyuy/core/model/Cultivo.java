package pe.muyuy.core.model;

import java.util.List;

/** Una fila de data/cultivos.json. */
public record Cultivo(String id, String nombre, String familia, List<String> zonas,
                      boolean fijaNitrogeno, Nivel toleraHelada, Nivel agua, int cicloMeses,
                      double tOptMin, double tOptMax, double valorMercado,
                      boolean cobertura, boolean raizProfunda) {

    public static final String DESCANSO = "descanso";

    public boolean esDescanso() { return DESCANSO.equals(id); }
}
