package pe.muyuy.core.comunidad;

import org.junit.jupiter.api.Test;
import pe.muyuy.core.model.MesClima;

import java.time.Duration;
import java.time.Instant;

import static org.junit.jupiter.api.Assertions.*;

/** Reglas del puntaje automático y del límite por IP (pueden fallar en silencio). */
class PuntajeYLimiteTest {

    private static MesClima mes(double probHelada, double lluvia, double balance, double tMin) {
        return new MesClima(6, probHelada, lluvia, 80, balance, 0, tMin, 18);
    }

    @Test
    void heladaSoloEsCreibleSiNasaRegistraFrio() {
        assertEquals(55, Puntaje.nasa("helada", mes(0.5, 5, -70, -1)));
        assertEquals(55, Puntaje.nasa("helada", mes(0.0, 5, -70, 1.5)));
        assertEquals(0, Puntaje.nasa("helada", mes(0.0, 200, 100, 18)), "helada en clima cálido = sospechosa");
        assertEquals(55, Puntaje.nasa("sequia", mes(0, 5, -70, 10)));
        assertEquals(55, Puntaje.nasa("lluvia_fuerte", mes(0, 150, 60, 10)));
        assertEquals(30, Puntaje.nasa("plaga", mes(0, 150, 60, 10)), "NASA no contrasta plagas: neutro");
        assertEquals(30, Puntaje.nasa("helada", null), "sin calendario: neutro");
    }

    @Test
    void consensoYEstados() {
        assertEquals(0, Puntaje.consenso(0));
        assertEquals(25, Puntaje.consenso(1));
        assertEquals(45, Puntaje.consenso(2));
        assertEquals(45, Puntaje.consenso(9));
        assertEquals("pendiente", Puntaje.estado(55));        // NASA sola no basta
        assertEquals("validada", Puntaje.estado(80));         // NASA + 1 vecino
        assertEquals("sospechosa", Puntaje.estado(25));       // solo un vecino y NASA lo contradice
        assertEquals("pendiente", Puntaje.estado(45));
        assertNotNull(Puntaje.motivoSospecha("helada", 0, 0));
        assertNull(Puntaje.motivoSospecha("helada", 55, 55));
    }

    @Test
    void limitePorIpEnVentana() {
        LimiteIp limite = new LimiteIp(3, Duration.ofHours(1));
        Instant t = Instant.parse("2026-11-14T10:00:00Z");
        assertTrue(limite.permitir("1.1.1.1", t));
        assertTrue(limite.permitir("1.1.1.1", t));
        assertTrue(limite.permitir("1.1.1.1", t));
        assertFalse(limite.permitir("1.1.1.1", t), "la cuarta se bloquea");
        assertTrue(limite.permitir("2.2.2.2", t), "otra IP no se afecta");
        assertTrue(limite.permitir("1.1.1.1", t.plus(Duration.ofMinutes(61))), "pasada la hora se reinicia");
    }
}
