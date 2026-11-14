package pe.muyuy.config;

import io.quarkus.runtime.configuration.ConfigUtils;
import io.quarkus.test.junit.QuarkusTest;
import io.quarkus.test.junit.QuarkusTestProfile;
import io.quarkus.test.junit.TestProfile;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.equalTo;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Arranca la app con application-prod.yml (como en Oracle). Solo se apunta data-dir
 * a ../data, igual que hace MUYUY_DATA_DIR. Si prod.yml se rompe, este test falla antes del deploy.
 */
@QuarkusTest
@TestProfile(PerfilProdTest.Prod.class)
class PerfilProdTest {

    public static class Prod implements QuarkusTestProfile {
        @Override public String getConfigProfile() { return "prod"; }
        @Override public Map<String, String> getConfigOverrides() { return Map.of("MUYUY_DATA_DIR", "../data",
                    "DB_URL", "${TEST_DB_URL:jdbc:postgresql://localhost:5432/muyuy_test}",
                    "DB_USER", "${TEST_DB_USER:postgres}"); }
    }

    @Test
    void arrancaEnProdYDatosListos() {
        assertTrue(ConfigUtils.getProfiles().contains("prod"));
        given().when().get("/q/health/ready").then().statusCode(200).body("status", equalTo("UP"));
    }
}
