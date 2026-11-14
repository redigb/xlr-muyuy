package pe.muyuy.core.comunidad;

import pe.muyuy.core.model.MesClima;

/**
 * Puntaje automático de una observación, 0..100 (SPECS_v2 §8):
 * hasta 55 por coincidir con el clima NASA + hasta 45 por consenso con otros dispositivos.
 */
public final class Puntaje {

    public static final int NASA_MAX = 55;
    public static final int NASA_NEUTRO = 30;      // NASA no puede contrastar ese tipo de evento
    public static final int CONSENSO_MAX = 45;

    private Puntaje() {}

    /** @param mes clima NASA del mes del evento en esa zona; null si no hay calendario (neutro) */
    public static int nasa(String tipo, MesClima mes) {
        if (mes == null) return NASA_NEUTRO;
        return switch (tipo) {
            case "helada" -> mes.tMin() <= 2.0 || mes.probHelada() >= 0.2 ? NASA_MAX : 0;
            case "sequia" -> mes.balanceHidricoMm() < 0 ? NASA_MAX : 15;
            case "lluvia_fuerte" -> mes.lluviaMm() >= 80 ? NASA_MAX : 20;
            default -> NASA_NEUTRO;
        };
    }

    /** @param otros dispositivos DISTINTOS que reportaron lo mismo (misma zona y tipo, ±3 días, no demo) */
    public static int consenso(int otros) {
        return otros <= 0 ? 0 : otros == 1 ? 25 : CONSENSO_MAX;
    }

    public static String estado(int puntaje) {
        return puntaje >= 70 ? "validada" : puntaje >= 40 ? "pendiente" : "sospechosa";
    }

    public static String motivoSospecha(String tipo, int nasa, int total) {
        if (total >= 40) return null;
        return nasa == 0 && "helada".equals(tipo)
                ? "Helada reportada en un mes sin frio segun NASA (T min > 2 C)"
                : "Sin coincidencia con NASA ni confirmacion de otros dispositivos";
    }
}
