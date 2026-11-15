package pe.muyuy.api;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

/** /api/red/publica (SPECS_v2 §9.3 y §15): anónima y sin demo. */
@QuarkusTest
class RedApiTest {

    private String registrar(boolean demo) {
        return given().contentType(ContentType.JSON).body(Map.of("demo", demo))
                .post("/api/dispositivos").then().statusCode(201).extract().path("token");
    }

    private void compartir(String token, String origen, String destino, boolean demo) {
        Map<String, Object> con = Map.of("origen", origen, "destino", destino, "tipo", "COMPARTIO",
                "paquete", "huanuco-sierra@1", "demo", demo);
        given().contentType(ContentType.JSON).header("Authorization", "Bearer " + token)
                .body(Map.of("observaciones", List.of(), "conexiones", List.of(con)))
                .post("/api/sync").then().statusCode(200);
    }

    @Test
    void redSinIdsRealesNiDemo() {
        String a = "disp-" + UUID.randomUUID();
        String b = "disp-" + UUID.randomUUID();
        String c = "disp-" + UUID.randomUUID();
        String demo = "disp-" + UUID.randomUUID();
        compartir(registrar(false), a, b, false);
        compartir(registrar(false), b, c, false);
        compartir(registrar(true), demo, a, true);

        String cuerpo = given().get("/api/red/publica").then().statusCode(200)
                .body("nodos.id", everyItem(matchesPattern("n\\d+")))
                .body("conexiones.origen", everyItem(matchesPattern("n\\d+")))
                .body("metricas.comparticiones", greaterThanOrEqualTo(2))
                .body("metricas.alcance_max", greaterThanOrEqualTo(2))
                .body("metricas.saltos_max", greaterThanOrEqualTo(2))
                .body("serie.size()", equalTo(30))
                .extract().asString();
        for (String real : List.of(a, b, c, demo)) {
            org.junit.jupiter.api.Assertions.assertFalse(cuerpo.contains(real), "no expone IDs reales");
        }
    }
}
