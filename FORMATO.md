# Qué envía Health Export

Una vez al día, la app manda desde el iPhone un **resumen en texto** de los datos de Apple Salud del día anterior y del sueño de la noche siguiente. Está pensado para que lo lea un bot: no hace falta ningún parser. Hay un ejemplo en `ejemplo-resumen.txt`.

## Cómo llega

```
POST <URL configurada en la app>
Content-Type: application/json
Authorization: Bearer <token>        (o Basic, o ninguna, según la app)

{"text": "Resumen de Apple Salud del lunes, 12 de octubre de 2026\n\nPasos: 9.842\n..."}
```

- El cuerpo es un JSON con un único campo, `text`, que contiene el resumen con saltos de línea. Suele ocupar 500–1.000 caracteres; con todos los tipos activados se queda por debajo de 4.000.
- Cualquier 2xx cuenta como recibido. Si la respuesta es otra, la app lo vuelve a intentar en el siguiente aviso de iOS.
- El botón "Probar conexión" envía `{"text": "Prueba de conexión de Health Export. Puedes ignorar este mensaje."}`.

## Cuándo llega

- Una vez al día, a partir de la hora elegida en la app (por defecto las 9:00). iOS decide el momento exacto y solo deja leer Salud con el iPhone desbloqueado, así que puede llegar algo más tarde.
- Si el iPhone lleva días sin enviar, recupera hasta 7 días pendientes, con **un mensaje por día**, del más antiguo al más reciente.
- El botón "Enviar resumen ahora" manda el resumen de ayer en cualquier momento. Puede repetir un día que ya llegó: el último mensaje de un día sustituye al anterior.

## Contenido

- Primera línea: `Resumen de Apple Salud del <día de la semana>, <fecha>`. Es el día al que se refieren los datos.
- Una línea por cada tipo de dato activado en la app que tenga datos ese día, con el nombre en español.
  - **Acumulados** (pasos, distancia, energía, minutos de ejercicio…): el total del día. Se calcula igual que en la app Salud, sin contar dos veces lo que registran a la vez el iPhone y el Watch.
  - **Medidas** (pulso, variabilidad, oxígeno, peso…): `media X, mín. Y, máx. Z`, o un único valor si solo hubo una medida o todas coinciden.
  - **Entrenamientos**: una línea por entrenamiento con tipo, hora de inicio, duración y, si existen, distancia, energía y pulso medio.
  - **Sueño**: la noche que empieza ese día. Por ejemplo, el resumen del 12 incluye la noche del 12 al 13. Da el total dormido, la hora de dormirse y de despertarse, el tiempo en cada fase (profundo, ligero, REM) y el tiempo despierto con el número de interrupciones.
- Última línea, si procede: `Sin datos: …`, con los tipos activados que no tuvieron datos ese día. Así se distingue "no hubo datos" de "no está activado".
- Unidades: `lpm` (latidos por minuto), `rpm` (respiraciones por minuto), `ms`, `kcal`, `km`, `kg`, `%`, `°C`, `ml/kg/min`, `min`. Decimales con coma.
