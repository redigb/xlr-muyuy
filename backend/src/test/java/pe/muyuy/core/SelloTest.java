package pe.muyuy.core;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import pe.muyuy.core.paquete.Sello;

import java.util.LinkedHashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

/** El hash no depende del orden de las claves y cambia si cambia un dato. */
class SelloTest {

    private final ObjectMapper mapper = new ObjectMapper();

    @Test
    void canonicoOrdenaClavesSinEspacios() throws Exception {
        var arbol = mapper.readTree("{ \"b\": 1, \"a\": { \"z\": [3, 2.0], \"y\": null } }");
        assertEquals("{\"a\":{\"y\":null,\"z\":[3,2.0]},\"b\":1}", Sello.canonico(mapper, arbol));
    }

    @Test
    void mismoContenidoMismoHashAunqueCambieElOrden() {
        Map<String, Object> a = new LinkedHashMap<>();
        a.put("x", 1); a.put("y", "dos");
        Map<String, Object> b = new LinkedHashMap<>();
        b.put("y", "dos"); b.put("x", 1);
        String h = Sello.hash(mapper, a, Map.of());
        assertEquals(h, Sello.hash(mapper, b, Map.of()));
        assertTrue(h.matches("sha256:[0-9a-f]{64}"));
        b.put("x", 2);
        assertNotEquals(h, Sello.hash(mapper, b, Map.of()));
    }
}
