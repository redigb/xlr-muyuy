package pe.muyuy.api;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;
import pe.muyuy.core.coordenada.FuenteClimaFalsa;
import pe.muyuy.core.paquete.Sello;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Prueba del flujo "Usar mi ubicación" (SPECS_v2 §10–11.1) y de los paquetes en inglés.
 * La fuente de clima es falsa (FuenteClimaFalsa): no sale a internet.
 */
@QuarkusTest
class CoordenadaApiTest {

    private final ObjectMapper json = new ObjectMapper();

    @Test
    void cualquierPuntoDaUnPaqueteSelladoYNoValidado() throws Exception {
        String cuerpo = given().queryParam("lat", -12.04).queryParam("lon", -77.03).queryParam("lang", "en")
                .get("/api/paquete/coordenada").then().statusCode(200)
                .body("paquete.meta.origen", equalTo("coordenada"))
                .body("paquete.meta.zona", nullValue())
                .body("paquete.meta.celda", equalTo("-12.0_-77.0"))
                .body("paquete.meta.validada_localmente", equalTo(false))
                .body("paquete.meta.idioma", equalTo("en"))
                .body("paquete.nucleo.zona.id", equalTo("celda_-12.0_-77.0"))
                .body("paquete.nucleo.rotaciones", not(empty()))
                .body("paquete.meta.extras", empty())
                .body("paquete.extras.imagen_satelital_b64", nullValue())
                .extract().asString();

        JsonNode doc = json.readTree(cuerpo).path("paquete");
        var paraHash = json.createObjectNode();
        paraHash.set("extras", doc.path("extras"));
        paraHash.set("nucleo", doc.path("nucleo"));
        assertEquals(doc.at("/meta/hash").asText(), "sha256:" + Sello.sha256(Sello.canonico(json, paraHash)),
                "el hash debe verificar en la app");
        for (JsonNode r : doc.at("/nucleo/rotaciones")) {
            assertFalse(r.path("es_practica_comun").asBoolean(), "sin práctica común fuera de Huánuco");
            assertEquals(0.5, r.at("/puntajes/ingresos").asDouble(), 1e-9, "ingresos neutros");
            assertNotEquals("alta", r.at("/confianza/clima").asText(), "confianza máxima media");
            assertTrue(r.path("validar_con_experto").asText().matches("^(Check|Ask).*"), "texto en inglés");
        }
        int mes = doc.at("/nucleo/inicio_siembra_mes").asInt();
        assertTrue(mes >= 1 && mes <= 12);
    }

    @Test
    void laMismaCeldaSaleDeLaCache() {
        int antes = FuenteClimaFalsa.LLAMADAS.get();
        given().queryParam("lat", 40.41).queryParam("lon", -3.70).get("/api/paquete/coordenada").then().statusCode(200);
        given().queryParam("lat", 40.30).queryParam("lon", -3.60).get("/api/paquete/coordenada").then().statusCode(200)
                .body("paquete.meta.celda", equalTo("40.5_-3.5"));
        assertEquals(antes + 1, FuenteClimaFalsa.LLAMADAS.get(), "un solo cálculo por celda");
    }

    @Test
    void conRiegoEsOtraVarianteDeLaMismaCelda() {
        String secano = given().queryParam("lat", 20.1).queryParam("lon", 30.1).get("/api/paquete/coordenada")
                .then().statusCode(200).body("paquete.nucleo.zona.riego", equalTo(false))
                .extract().path("paquete.meta.hash");
        int antes = FuenteClimaFalsa.LLAMADAS.get();
        given().queryParam("lat", 20.1).queryParam("lon", 30.1).queryParam("riego", true).get("/api/paquete/coordenada")
                .then().statusCode(200)
                .body("paquete.meta.celda", equalTo("20.0_30.0"))
                .body("paquete.nucleo.zona.riego", equalTo(true))
                .body("paquete.meta.hash", not(equalTo(secano)));
        assertEquals(antes + 1, FuenteClimaFalsa.LLAMADAS.get(), "con riego no reutiliza el paquete de secano");
        given().queryParam("lat", 20.1).queryParam("lon", 30.1).queryParam("riego", true).get("/api/paquete/coordenada")
                .then().statusCode(200);
        assertEquals(antes + 1, FuenteClimaFalsa.LLAMADAS.get(), "pero sí su propia caché");
    }

    @Test
    void coordenadaInvalidaDa400() {
        given().queryParam("lat", 75).queryParam("lon", 10).get("/api/paquete/coordenada").then().statusCode(400);
        given().queryParam("lat", 10).get("/api/paquete/coordenada").then().statusCode(400);
    }

    @Test
    void siNasaNoRespondeDa504() {
        given().queryParam("lat", FuenteClimaFalsa.LAT_FALLA + 0.1).queryParam("lon", 10)
                .get("/api/paquete/coordenada").then().statusCode(504).body("error", containsString("NASA"));
    }

    @Test
    void zonaOficialEnInglesEsOtroPaqueteConSuPropioHash() {
        String es = given().get("/api/paquete/huanuco-sierra").then().statusCode(200)
                .body("paquete.meta.idioma", equalTo("es")).extract().path("paquete.meta.hash");
        given().queryParam("lang", "en").get("/api/paquete/huanuco-sierra").then().statusCode(200)
                .body("paquete.meta.idioma", equalTo("en"))
                .body("paquete.meta.validada_localmente", equalTo(true))
                .body("paquete.meta.hash", not(equalTo(es)));
        given().queryParam("lang", "en").get("/api/paquete/huanuco-sierra/version").then().statusCode(200)
                .body("version", greaterThanOrEqualTo(1));
    }
}
