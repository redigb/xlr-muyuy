package pe.muyuy;

import io.quarkus.test.junit.QuarkusTest;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.equalTo;
import static org.hamcrest.Matchers.notNullValue;
import static org.hamcrest.Matchers.nullValue;
import static org.hamcrest.Matchers.hasItem;

/** Lo mínimo que la app y el deploy (GitHub Actions) necesitan que responda. */
@QuarkusTest
class ApiBasicaTest {

    @Test
    void holaResponde() {
        given().when().get("/").then().statusCode(200)
               .body("app", equalTo("muyuy")).body("estado", equalTo("ok"));
    }

    @Test
    void saludReadyEnVerdeConDatos() {
        given().when().get("/q/health/ready").then().statusCode(200)
               .body("status", equalTo("UP"))
               .body("checks.name", hasItem("datos"))
               .body("checks.find { it.name == 'datos' }.data.zonas", equalTo(4))
               .body("checks.find { it.name == 'datos' }.data.sin_calendario", equalTo("[]"));
    }

    @Test
    void contratoOpenApiPublicado() {
        given().when().get("/q/openapi?format=json").then().statusCode(200)
               .body("info.title", equalTo("Muyuy API"));
    }

    /** La doc debe usar los mismos nombres que el JSON real (snake_case) y explicar cada campo en inglés. */
    @Test
    void openApiDocumentaCamposComoElJsonReal() {
        given().when().get("/q/openapi?format=json").then().statusCode(200)
               .body("components.schemas.Rotacion.properties.es_practica_comun.description", containsString("traditional"))
               .body("components.schemas.Rotacion.properties.cultivo_inicial", notNullValue())
               .body("components.schemas.Meta.properties.validada_localmente", notNullValue())
               .body("components.schemas.Rotacion.properties.esPracticaComun", nullValue());
    }

    @Test
    void corsHabilitadoParaLaApp() {
        given().header("Origin", "https://app.ejemplo.com")
               .when().get("/").then().statusCode(200)
               .header("Access-Control-Allow-Origin", equalTo("https://app.ejemplo.com"));
    }
}
