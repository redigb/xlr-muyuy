# Quickstart: validar el Motor v2

```bash
cd backend
./mvnw verify                       # Windows: mvnw.cmd verify
```

Resultado esperado: todo en verde, incluidas las pruebas nuevas.
- `MotorFlujoTest`: las 4 zonas de `data/` → candidatas válidas. Sierra con 6 a 10 por cultivo inicial, determinista, y selva distinta de sierra.
- `MotorReglasTest`: nunca papa → papa, nunca familia repetida seguida, `esApto` rechaza helada letal, lluvia insuficiente y temperatura fuera de rango, y los puntajes están entre 0 y 1.
