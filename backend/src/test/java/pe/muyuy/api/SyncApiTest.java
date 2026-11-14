package pe.muyuy.api;

import io.agroal.api.AgroalDataSource;
import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import io.restassured.response.ValidatableResponse;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;
import pe.muyuy.core.comunidad.Puntaje;
import pe.muyuy.core.data.RepositorioCalendarios;

import java.sql.SQLException;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

/**
 * Prueba del flujo de uso (constitución II): lo que hace la app cuando recupera señal.
 * Registro anónimo → sync → reenvío sin duplicar → un vecino confirma → la alerta entra al paquete.
 */
@QuarkusTest
class SyncApiTest {

    private static final String SIERRA = "huanuco-sierra";
    private final LocalDate ayer = LocalDate.now(ZoneOffset.UTC).minusDays(1);

    @Inject AgroalDataSource ds;
    @Inject RepositorioCalendarios calendarios;

    // ---------- ayudas

    private String registrar(boolean demo) {
        return given().contentType(ContentType.JSON).body(Map.of("demo", demo))
                .post("/api/dispositivos").then().statusCode(201)
                .body("id", notNullValue()).extract().path("token");
    }

    private Map<String, Object> obs(String zona, String tipo, LocalDate fecha) {
        Map<String, Object> o = new HashMap<>();
        o.put("id_local", UUID.randomUUID().toString());
        o.put("zona_id", zona);
        o.put("tipo", tipo);
        o.put("fecha_evento", fecha.toString());
        o.put("lat_aprox", -9.90456);
        o.put("lon_aprox", -75.98765);
        o.put("demo", false);
        return o;
    }

    private ValidatableResponse sync(String token, List<Map<String, Object>> observaciones, List<Map<String, Object>> conexiones) {
        return given().contentType(ContentType.JSON).header("Authorization", "Bearer " + token)
                .body(Map.of("observaciones", observaciones, "conexiones", conexiones))
                .post("/api/sync").then();
    }

    private long contar(String sql, Object... params) throws SQLException {
        try (var c = ds.getConnection(); var ps = c.prepareStatement(sql)) {
            for (int i = 0; i < params.length; i++) ps.setObject(i + 1, params[i]);
            try (var rs = ps.executeQuery()) { rs.next(); return rs.getLong(1); }
        }
    }

    /** Un tipo de evento que el clima NASA de ayer en sierra respalda (55 puntos), o null. */
    private String tipoCreibleAyer() {
        var mes = calendarios.deZona(SIERRA).orElseThrow().mes(ayer.getMonthValue());
        for (String t : List.of("lluvia_fuerte", "sequia", "helada")) if (Puntaje.nasa(t, mes) == Puntaje.NASA_MAX) return t;
        return null;
    }

    // ---------- pruebas

    @Test
    void registroAnonimoYTokenObligatorio() throws SQLException {
        String token = registrar(false);
        assertTrue(token.contains("."));
        assertEquals(0, contar("select count(*) from dispositivos where token_hash = ?", token), "nunca se guarda el token en claro");

        given().contentType(ContentType.JSON).body("{}").post("/api/sync").then().statusCode(401);
        sync("no-es-un-token", List.of(), List.of()).statusCode(401);
        sync(UUID.randomUUID() + ".inventado", List.of(), List.of()).statusCode(401);
        sync(token, List.of(), List.of()).statusCode(200).body("aceptadas", equalTo(0));
    }

    @Test
    void flujoCompletoDeUnaAlertaDeLaComunidad() throws SQLException {
        String tipo = tipoCreibleAyer();
        assumeTrue(tipo != null, "el clima de este mes no respalda ningún tipo contrastable");
        int versionAntes = given().get("/api/paquete/" + SIERRA + "/version").then().extract().path("version");

        // 1) Un agricultor reporta: NASA lo respalda pero nadie lo confirma → pendiente
        String a = registrar(false);
        var obsA = obs(SIERRA, tipo, ayer);
        UUID idA = UUID.fromString((String) obsA.get("id_local"));
        sync(a, List.of(obsA), List.of()).statusCode(200)
                .body("aceptadas", equalTo(1)).body("rechazadas", equalTo(0))
                .body("detalle[0].estado", equalTo("pendiente")).body("detalle[0].puntaje", equalTo(55));

        // 2) Reenvío (sin señal estable): no se duplica; la ubicación quedó redondeada a ~1 km
        sync(a, List.of(obsA), List.of()).statusCode(200).body("aceptadas", equalTo(1));
        assertEquals(1, contar("select count(*) from observaciones where id_local = ?", idA));
        assertEquals(1, contar("select count(*) from observaciones where id_local = ? and lat_aprox = -9.9", idA));

        // 3) Un demo reporta lo mismo: no cuenta como consenso
        sync(registrar(true), List.of(obs(SIERRA, tipo, ayer)), List.of()).statusCode(200).body("aceptadas", equalTo(1));
        sync(a, List.of(obsA), List.of()).body("detalle[0].estado", equalTo("pendiente"));

        // 4) Un vecino real lo confirma → ambas validadas
        String b = registrar(false);
        sync(b, List.of(obs(SIERRA, tipo, ayer)), List.of()).statusCode(200)
                .body("detalle[0].estado", equalTo("validada")).body("detalle[0].puntaje", equalTo(80));
        sync(a, List.of(obsA), List.of()).body("detalle[0].estado", equalTo("validada"));

        // 5) La alerta entra al paquete de la zona: versión nueva, 2 confirmaciones (el demo no cuenta)
        String ruta = "paquete.nucleo.alertas_comunidad.find { it.tipo == \"" + tipo + "\" && it.fecha == \"" + ayer + "\" }.confirmaciones";
        given().get("/api/paquete/" + SIERRA).then().statusCode(200)
                .body("paquete.meta.version", greaterThan(versionAntes))
                .body(ruta, equalTo(2));
    }

    @Test
    void heladaEnLaSelvaEsSospechosa() {
        sync(registrar(false), List.of(obs("huanuco-selva", "helada", ayer)), List.of()).statusCode(200)
                .body("aceptadas", equalTo(1))
                .body("detalle[0].estado", equalTo("sospechosa"))
                .body("detalle[0].motivo", containsString("NASA"));
    }

    @Test
    void rechazaDatosSinSentidoConSuMotivo() {
        var futura = obs(SIERRA, "helada", LocalDate.now(ZoneOffset.UTC).plusDays(10));
        var tipoRaro = obs(SIERRA, "ovni", ayer);
        var zonaRara = obs("marte", "helada", ayer);
        var lejos = obs(SIERRA, "helada", ayer);
        lejos.put("lat_aprox", 123.0);
        sync(registrar(false), List.of(futura, tipoRaro, zonaRara, lejos), List.of()).statusCode(200)
                .body("aceptadas", equalTo(0)).body("rechazadas", equalTo(4))
                .body("detalle.motivo", hasItems("fecha futura", "tipo desconocido", "zona desconocida", "ubicacion invalida"));
    }

    @Test
    void limiteDiarioPorDispositivo() {
        List<Map<String, Object>> muchas = new ArrayList<>();
        for (int i = 0; i < 52; i++) muchas.add(obs("global-demo", "otro", ayer));
        sync(registrar(true), muchas, List.of()).statusCode(200)
                .body("aceptadas", equalTo(50)).body("rechazadas", equalTo(2))
                .body("detalle.motivo", hasItem("limite_diario"));
    }

    @Test
    void conexionesIdempotentes() throws SQLException {
        String origen = "disp-" + UUID.randomUUID();
        Map<String, Object> con = Map.of("origen", origen, "destino", "disp-yo", "tipo", "COMPARTIO",
                "paquete", SIERRA + "@1", "demo", false);
        Map<String, Object> invalida = Map.of("origen", origen, "destino", origen, "tipo", "COMPARTIO");
        String token = registrar(false);
        sync(token, List.of(), List.of(con, invalida)).statusCode(200).body("conexiones", equalTo(1));
        sync(token, List.of(), List.of(con)).statusCode(200);
        assertEquals(1, contar("select count(*) from conexiones where origen = ?", origen));
    }
}
