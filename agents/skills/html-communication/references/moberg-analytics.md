# Moberg Analytics template

Use this template only when Tony asks for it by name ("the Moberg Analytics template" or theme). Every other page, Moberg work and pages for outside readers included, uses the skill's defaults.

It's a theme for pages Tony shares with people outside Moberg Analytics, such as customers, research sites and partners: a guide, a changelog, an analysis report. The genre contract for the page (plan, report, decision) still applies. The template adds the frame and the rules for an outside reader.

## Frame

Copy `templates/moberg-analytics.html`. Keep its palette, logo header, freshness line and footer, and build `main` for the subject. The stylesheet has components to use where they help: `.lead`, `.steps` (a short workflow strip), `.panel`, `.note`, `.warn`, `h2 .num` (numbered sections), tables in `.table-wrap`, `details`, and `.links` cards.

The page stays light in every reader's setting. `data-theme="light"` on `<html>` keeps `highlight.mts` code blocks on the light theme to match the page; without it they turn dark on a white page.

## Outside reader

- **Company name.** "Moberg Analytics" every time: title, prose, alt text, footer.
- **The reader's setup and words.** Commands, folders and names as the reader sees them, with `<placeholders>` for their own values.
- **Freshness line.** The date plus what the page covers: software versions for a guide or changelog (`Updated 19 November 2026 · connect-client 3.3.0`), the data and its date range for an analysis. Leave out internal commits.
- **Internal details.** The page holds what the reader can see, run or rely on. Leave out local paths (`/vault`, `/tmp`, `/home`), hostnames, internal repos and branches, Jira keys and ticket names, colleague names other than the sender, internal tooling, and internal-only claims or features. A string the reader must type, such as an image tag, stays verbatim.
- **Patient data.** Apply `~/notes/04-projects/moberg/data-policy.md`: no patient identifiers beyond what the reader already holds.
- **Contact.** The sender for a report or analysis; support@moberganalytics.com for product help in a guide or changelog.

## Before publishing

1. Run the skill's build and lint steps.
2. Run the `unslop` skill on the prose.
3. Check for leaks; every hit is removed or is a string the reader must type:

   ```sh
   grep -nP '/vault|/tmp/|/home/|\.ts\.net|sietch|jacurutu|tleilax|\b[A-Z][A-Z0-9]+-\d+\b|Moberg(?! Analytics)' page.html
   ```

## Sharing

The reader gets the pinned raw link to one version, `https://page-bin.com/raw/<id>/<token>/v/<N>/<file>.html`, in place of the viewer URL. It has no PageBin header bar, and the page doesn't change under the reader.

To build it, publish as usual and take the new version's `/p/<id>/<token>/v/<N>` URL from `pagebin versions <page>`. Change `/p/` to `/raw/` and append the page's file name. Each update is a new version with a new raw link, so hand Tony the new link to send. He keeps the viewer URL for his own review.
