package pe.muyuy.config;

import io.quarkus.runtime.configuration.ConfigUtils;
import io.quarkus.test.junit.QuarkusTest;
import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** application.yml + application-test.yml se cargan y se combinan bien. */
@QuarkusTest
class PerfilTestTest {

    @ConfigProperty(name = "muyuy.data-dir") String dataDir;
    @ConfigProperty(name = "groq.api-key") String groqKey;
    @ConfigProperty(name = "quarkus.jackson.property-naming-strategy") String naming;

    @Test
    void cargaPerfilTest() {
        assertTrue(ConfigUtils.getProfiles().contains("test"));
        assertEquals("../data", dataDir);
        assertEquals("test-sin-clave", groqKey);
        assertEquals("SNAKE_CASE", naming);          // viene de la base application.yml
    }
}
