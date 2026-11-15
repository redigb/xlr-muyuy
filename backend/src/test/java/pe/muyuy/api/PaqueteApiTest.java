package pe.muyuy.api;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.agroal.api.AgroalDataSource;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;
import pe.muyuy.core.paquete.ServicioPaquetes;
import pe.muyuy.core.paquete.Sello;

import java.sql.SQLException;
import java.util.List;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Prueba del flujo de uso (constitución II): lo que hace la app con señal.
 * /api/zonas → /api/paquete/{zona}/version → /api/paquete/{zona} → verificar el hash.
 */
@QuarkusTest
class PaqueteApiTest {

    private static final List<String> ZONAS = List.of("huanuco-sierra", "huanuco-valle", "huanuco-selva", "global-demo");

    @Inject ServicioPaquetes servicio;
    @Inject AgroalDataSource ds;
    private final ObjectMapper json = new ObjectMapper();

    @Test
    void saludYZonas() {
        given().get("/api/salud").then().statusCode(200).body("ok", equalTo(true));
        given().get("/api/zonas").then().statusCode(200)
               .body("id", hasItems(ZONAS.toArray()))
               .body("find { it.id == 'huanuco-sierra' }.cultivos_iniciales", hasItem("papa"));
    }

    @Test
    void lasCuatroZonasDanUnPaqueteCompletoYVerificable() throws Exception {
        for (String zona : ZONAS) {
            String cuerpo = given().get("/api/paquete/" + zona).then().statusCode(200)
                    .body("paquete.meta.formato", equalTo(2))
                    .body("paquete.meta.origen", equalTo("zona_oficial"))
                    .body("paquete.meta.zona", equalTo(zona))
                    .body("paquete.meta.validada_localmente", equalTo(!zona.equals("global-demo")))
                    .body("paquete.meta.secciones.calendario.valido_hasta", notNullValue())
                    .body("paquete.nucleo.calendario.size()", equalTo(12))
                    .body("paquete.nucleo.inicio_siembra_mes", equalTo(10))
                    .body("paquete.nucleo.rotaciones.size()", greaterThanOrEqualTo(3))
                    .body("paquete.nucleo.rotaciones.explicacion", everyItem(not(emptyOrNullString())))
                    .body("paquete.nucleo.cultivos.size()", greaterThanOrEqualTo(3))
                    .body("paquete.meta.extras", contains("imagen"))
                    .body("paquete.extras.imagen_satelital_b64", equalTo(
                            java.util.Base64.getEncoder().encodeToString(pe.muyuy.core.imagen.FuenteImagenFalsa.JPEG)))
                    .extract().asString();

            // La app recalcula el hash con lo que recibió
            JsonNode p = json.readTree(cuerpo).path("paquete");
            var paraHash = json.createObjectNode();
            paraHash.set("extras", p.path("extras"));
            paraHash.set("nucleo", p.path("nucleo"));
            assertEquals(p.at("/meta/hash").asText(), "sha256:" + Sello.sha256(Sello.canonico(json, paraHash)), zona);
        }
    }

    @Test
    void versionCoincideConElPaqueteYEsEstable() {
        int v = given().get("/api/paquete/huanuco-sierra/version").then().statusCode(200)
                .body("hash", startsWith("sha256:")).extract().path("version");
        given().get("/api/paquete/huanuco-sierra").then().body("paquete.meta.version", equalTo(v));

        // Regenerar sin cambios: misma versión y mismo hash
        var antes = servicio.obtener("huanuco-sierra").orElseThrow();
        var despues = servicio.regenerar("huanuco-sierra").orElseThrow();
        assertEquals(antes.version(), despues.version());
        assertEquals(antes.hash(), despues.hash());
    }

    @Test
    void versionSubeSoloSiElContenidoCambia() throws SQLException {
        var antes = servicio.obtener("huanuco-valle").orElseThrow();
        // Simula que el paquete guardado era distinto (otro hash)
        try (var c = ds.getConnection();
             var ps = c.prepareStatement("update paquetes set hash = 'sha256:viejo' where clave = ?")) {
            ps.setString(1, antes.clave());
            assertEquals(1, ps.executeUpdate());
        }
        var despues = servicio.regenerar("huanuco-valle").orElseThrow();
        assertEquals(antes.version() + 1, despues.version());
        given().get("/api/paquete/huanuco-valle/version").then().body("version", equalTo(despues.version()));
    }

    @Test
    void zonaDesconocidaDa404() {
        given().get("/api/paquete/no-existe").then().statusCode(404).body("error", containsString("no-existe"));
        given().get("/api/paquete/no-existe/version").then().statusCode(404);
    }

    @Test
    void cadaDescargaSeCuenta() throws SQLException {
        long antes = descargas();
        given().get("/api/paquete/huanuco-selva").then().statusCode(200);
        assertEquals(antes + 1, descargas());
    }

    private long descargas() throws SQLException {
        try (var c = ds.getConnection();
             var rs = c.createStatement().executeQuery("select count(*) from descargas where clave_paquete like 'huanuco-selva@%'")) {
            rs.next();
            return rs.getLong(1);
        }
    }
}
