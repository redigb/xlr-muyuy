# Muyuy landing

From the repository root, install dependencies with `npm ci`.

- Development: from `landing/`, run `../node_modules/.bin/astro dev --background`.
- Production build: `npm run build -- --root landing`
- Cloudflare Pages output directory: `landing/dist`. Use the repository root for the build command.

Set these public build variables when the team provides the approved assets:

| Variable | Value |
| --- | --- |
| `PUBLIC_MUYUY_VIDEO_EMBED_URL` | Embeddable URL for the 30-second video |
| `PUBLIC_MUYUY_APK_URL` | Signed Android APK URL |
| `PUBLIC_MUYUY_APK_SHA256` | 64-character hexadecimal SHA-256 of that APK |
| `PUBLIC_MUYUY_GITHUB_URL` | Public project repository |

The terrain's sample calendar is illustrative. Add field-test media and a quote after obtaining consent, and add the names of team members who approve their inclusion.

The language picker starts in English and saves the visitor's selection. The Quechua copy uses provisional Chanka wording. Review the Quechua and Aymara copy with speakers before public release, especially if the pilot needs a Huánuco Quechua variety.
