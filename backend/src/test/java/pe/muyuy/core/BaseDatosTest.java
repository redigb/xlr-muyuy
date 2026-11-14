package pe.muyuy.core;

import io.agroal.api.AgroalDataSource;
import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import org.junit.jupiter.api.Test;

import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.hasItem;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Flujo: la app arranca, Flyway crea el esquema y la salud reporta la base en UP. */
@QuarkusTest
class BaseDatosTest {

    @Inject AgroalDataSource ds;

    @Test
    void esquemaCreadoPorFlyway() throws SQLException {
        List<String> tablas = new ArrayList<>();
        try (var c = ds.getConnection();
             var rs = c.createStatement().executeQuery(
                     "select table_name from information_schema.tables where table_schema = 'public'")) {
            while (rs.next()) tablas.add(rs.getString(1));
        }
        assertTrue(tablas.containsAll(List.of("dispositivos", "observaciones", "conexiones", "paquetes", "descargas")),
                "tablas: " + tablas);
    }

    @Test
    void saludIncluyeBaseDeDatos() {
        given().when().get("/q/health/ready").then().statusCode(200)
               .body("status", equalTo("UP"))
               .body("checks.name", hasItem("Database connections health check"));
    }
}
