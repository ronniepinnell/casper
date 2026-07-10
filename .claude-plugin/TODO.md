# UNVERIFIED packaging — verify before publishing

plugin.json and marketplace.json follow the Claude Code plugin spec as known
at authoring time (marketplace.json: name/owner/plugins[{name,source,description}];
plugin.json: name/version/description/author/...). The spec has shifted before —
validate against current docs (`/plugin marketplace add`) in a clean Claude Code
profile before submitting anywhere. Skills auto-discover from skills/; hooks may
need a `hooks` field in plugin.json per the current spec.
