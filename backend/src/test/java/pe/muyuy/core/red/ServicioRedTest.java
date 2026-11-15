package pe.muyuy.core.red;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class ServicioRedTest {

    private static String[] e(String o, String d) { return new String[]{o, d, "2026-11-14"}; }

    @Test
    void cadenaYAbanico() {
        // a→b→c→d (3 saltos) y x→{1,2,3,4} (alcance 4, 1 salto)
        var aristas = List.of(e("a", "b"), e("b", "c"), e("c", "d"),
                e("x", "1"), e("x", "2"), e("x", "3"), e("x", "4"));
        assertArrayEquals(new int[]{4, 3}, ServicioRed.alcanceYSaltos(aristas));
    }

    @Test
    void ciclosNoCuentanDosVecesYHayTopeDeCincoSaltos() {
        assertArrayEquals(new int[]{2, 2}, ServicioRed.alcanceYSaltos(List.of(e("a", "b"), e("b", "c"), e("c", "a"))));
        var larga = List.of(e("0", "1"), e("1", "2"), e("2", "3"), e("3", "4"), e("4", "5"), e("5", "6"), e("6", "7"));
        assertEquals(5, ServicioRed.alcanceYSaltos(larga)[1]);
    }

    @Test
    void sinConexionesTodoEnCero() {
        assertArrayEquals(new int[]{0, 0}, ServicioRed.alcanceYSaltos(List.of()));
        assertTrue(ServicioRed.alias(List.of()).isEmpty());
    }

    @Test
    void aliasUnoPorDispositivo() {
        var alias = ServicioRed.alias(List.of(e("disp-a", "disp-b"), e("disp-b", "disp-c")));
        assertEquals(3, alias.size());
        assertEquals(3, alias.values().stream().distinct().count());
        alias.values().forEach(v -> assertTrue(v.matches("n[1-3]")));
    }
}
