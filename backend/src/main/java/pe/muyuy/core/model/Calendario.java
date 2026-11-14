package pe.muyuy.core.model;

import java.util.List;

/** data/calendario_<zonaId>.json (lo genera la persona de datos). anios = anios de datos NASA. */
public record Calendario(Zona zona, String fuente, Integer anios, List<MesClima> calendario) {

    /** @param mes 1..12 (acepta valores fuera de rango, p.ej. 14 -> 2) */
    public MesClima mes(int mes) {
        int m = Math.floorMod(mes - 1, 12) + 1;
        return calendario.stream().filter(c -> c.mes() == m).findFirst()
                .orElseThrow(() -> new IllegalStateException("Calendario sin mes " + m));
    }
}
