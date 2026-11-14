<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/img/muyuy-logo-blanco.png">
    <img src="docs/img/muyuy-logo.png" alt="Muyuy" width="420">
  </picture>
</p>

<p align="center">
  NASA Space Apps Challenge 2026 · <i>Field Shift: Adapting Farms with NASA Data</i> · Pilot: Huánuco, Peru
</p>

<p align="center">
  🌐 <b>Live API:</b> <a href="https://muyuy-bk.rdev7.net.pe/q/swagger-ui">muyuy-bk.rdev7.net.pe/q/swagger-ui</a>
</p>

## Why "Muyuy"?

**Muyuy** is a Quechua word meaning *"to turn, to go around, to rotate"*. In the Andes, rotating crops and resting
the land in turns is an ancestral practice. Climate change is now shifting frosts, rains and droughts, so the old
calendar no longer fits every field.

The name sums up the project: **help farmers turn their land wisely**, so they choose the next crop in the rotation with
**NASA climate data**, explained in their own words.

## The problem

Smallholder farmers in Huánuco (Peru) decide what to plant next from tradition: *"after potato, more potato"*.
With a changing climate, that habit raises the risk of frost losses, water stress and soil depletion.
They also farm where **there is no mobile signal**.

## The solution

1. **NASA POWER** climate data becomes a monthly agro-climatic calendar for each zone: frost risk, rainfall,
   evapotranspiration and water balance.
2. A **transparent, deterministic engine** combines that calendar with crop requirements and agronomic rules. It
   compares the farmer's usual rotation with better-adapted alternatives on water, soil, income and climate risk.
   Every score shows its **confidence level**.
3. The result is sealed into a small **offline package** (~2 KB). The phone downloads it once and works **without
   internet**, and can pass it to a neighbor's phone.
4. **AI only translates** the results into plain language. It never chooses or scores a rotation.

## What's in this repository

| Folder | What it is | Docs |
|---|---|---|
| [`backend/`](backend/) | Java 25 + Quarkus API: rotation engine, sealed packages, community sync, AI explanations | [backend/README.md](backend/README.md) |
| [`app/`](app/) | Flutter app (Android/web): offline packages, rotation options, calendar, soil photo hint | [app/README.md](app/README.md) |
| [`landing/`](landing/) | Public landing page (Astro + React + Three.js 3D terrain) | `pnpm dev` |
| [`data/`](data/) | Climate calendars (NASA POWER), crops, agronomic rules, zones | |
| [`docs/`](docs/) | Specs, progress log, NASA API tester, AI model evaluation | |
| [`scripts/`](scripts/) | Data and evaluation scripts | |
| [`specs/`](specs/) | Feature specs (spec-kit) | |

Each part has its own CI and only builds when its folder changes. Pushes to `main` that touch the backend are
**deployed automatically** to Oracle Cloud.

## NASA data

| Resource | Use |
|---|---|
| [NASA POWER](https://power.larc.nasa.gov/) (monthly, 1985–2024) | Frost probability, rainfall, evapotranspiration, water balance, temperature per zone |
| GIBS, SMAP and others | Explored for future layers ([docs/ApisNASA.html](docs/ApisNASA.html)) |

Crop parameters are based on FAO ECOCROP / FAO-56. Current calendars in `data/` are placeholders (`"anios": 0`) until the
real NASA POWER export is loaded with the same format.

## AI usage

Rotation explanations are written by **Groq (`openai/gpt-oss-120b`)** from the engine's output. If it is unavailable,
a fixed template is used. The model was chosen with an evaluation on real packages:
[docs/ai-model-evaluation.md](docs/ai-model-evaluation.md).

## Quick start

| Part | Command |
|---|---|
| Backend | `cd backend && ./mvnw quarkus:dev` → http://localhost:8080/q/swagger-ui |
| App | `cd app && flutter pub get && flutter run` (Flutter stable, Dart 3.14+) |
| Landing | `cd landing && pnpm install && pnpm dev` → http://localhost:4321 |
| Everything as in production | `cp .env.example .env && docker compose up -d --build` |

## Team

| Member | Role |
|---|---|
| [@redigb](https://github.com/redigb) | Backend, engine, infrastructure and deployment |
| [@LeoLucasC](https://github.com/LeoLucasC) | Flutter app |
| [@ClemDYhoy](https://github.com/ClemDYhoy) | Landing page and 3D terrain |
| [@LuisFc11](https://github.com/LuisFc11) | NASA API research |

## License

MIT
