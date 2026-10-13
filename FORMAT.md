# What Health Export sends

Once a day, the app sends a **plain-text summary** from the iPhone with the previous day's Apple Health data and the sleep of the following night. It's meant to be read by a bot, so no parser is needed. The summary text is in Spanish; see [`example-summary.txt`](example-summary.txt) for a sample.

## Request

```
POST <URL set in the app>
Content-Type: application/json
Authorization: Bearer <token>        (or Basic, or none, as set in the app)

{"text": "Resumen de Apple Salud del lunes, 12 de octubre de 2026\n\nPasos: 9.842\n..."}
```

- The body is JSON with a single field, `text`, holding the summary with line breaks. It's usually 500–1,000 characters, and stays under 4,000 even with every data type enabled.
- Any 2xx counts as received. On any other response, the app tries again the next time iOS wakes it.
- The "Probar conexión" (test connection) button sends `{"text": "Prueba de conexión de Health Export. Puedes ignorar este mensaje."}`.

## When it arrives

- Once a day, after the time chosen in the app (9:00 by default). iOS decides the exact moment and only allows Health data to be read while the iPhone is unlocked, so it may arrive somewhat later.
- If the iPhone hasn't sent for a few days, it catches up on up to 7 pending days, **one message per day**, oldest first.
- The "Enviar resumen ahora" (send summary now) button sends yesterday's summary at any time. It may repeat a day that already arrived; the latest message for a day replaces the earlier one.

## Content

Each line starts with the data type's name in Spanish. The words in parentheses below are the literal text in the summary.

- First line: `Resumen de Apple Salud del <weekday>, <date>`, the day the data refers to.
- One line for each data type enabled in the app that has data that day.
  - **Cumulative** (steps, distance, energy, exercise minutes…): the day's total. It's computed the same way as in the Health app, without double counting what the iPhone and the Watch record at the same time.
  - **Measurements** (heart rate, HRV, blood oxygen, weight…): average, minimum and maximum (`media X, mín. Y, máx. Z`), or a single value if there was only one reading or all readings match.
  - **Workouts** (`Entrenamientos`): one line per workout with its type, start time, duration and, when available, distance, energy and average heart rate.
  - **Sleep** (`Sueño`): the night that starts that day. For example, the summary for the 12th includes the night of the 12th to the 13th. It gives the total time asleep, when you fell asleep and woke up, the time in each stage: deep (`Profundo`), core (`Ligero`) and REM. It also gives the time awake (`Despierto`) with the number of interruptions (`interrupciones`).
- Last line, when needed: `Sin datos: …` ("no data"), listing the enabled types that had no data that day. This tells "there was no data" apart from "not enabled".
- Units: `lpm` (heartbeats per minute), `rpm` (breaths per minute), `ms`, `kcal`, `km`, `kg`, `%`, `°C`, `ml/kg/min`, `min`. Decimals use a comma.
