package pe.muyuy.core.paquete;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Hash verificable del paquete: "sha256:" + SHA-256 del JSON canónico de {extras, nucleo}.
 * JSON canónico = claves ordenadas alfabéticamente en todos los niveles, sin espacios, UTF-8.
 * La app repite el mismo cálculo sobre lo que recibió; si no coincide, rechaza el paquete.
 */
public final class Sello {

    private Sello() {}

    public static String hash(ObjectMapper mapper, Object nucleo, Object extras) {
        Map<String, Object> cuerpo = new LinkedHashMap<>();
        cuerpo.put("extras", extras);
        cuerpo.put("nucleo", nucleo);
        return "sha256:" + sha256(canonico(mapper, mapper.valueToTree(cuerpo)));
    }

    /** Sirve tanto para objetos Java (ya convertidos a árbol) como para JSON recibido. */
    public static String canonico(ObjectMapper mapper, JsonNode arbol) {
        try {
            Object plano = mapper.treeToValue(arbol, Object.class);
            return mapper.copy()
                    .configure(SerializationFeature.ORDER_MAP_ENTRIES_BY_KEYS, true)
                    .configure(SerializationFeature.INDENT_OUTPUT, false)
                    .writeValueAsString(plano);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("No se pudo generar el JSON canónico", e);
        }
    }

    public static String sha256(String texto) {
        try {
            byte[] d = MessageDigest.getInstance("SHA-256").digest(texto.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(d);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
