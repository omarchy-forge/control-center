.pragma library

var MAX_SERVICES = 16
var ID_RE = /^[a-zA-Z0-9_-]{1,64}$/
var URL_RE = /^https?:\/\//

function isNonEmptyString(v, maxLen) {
  return typeof v === "string" && v.length > 0 && v.length <= maxLen
}

// Resolves a service's configured `cwd` against the project directory,
// rejecting anything that would escape it (absolute paths, ".." segments).
// Returns null if the value is unsafe.
function resolveCwd(projectPath, cwd) {
  var base = String(projectPath || "").replace(/\/+$/, "")
  if (base === "") return null
  if (cwd === undefined || cwd === null || cwd === "") return base
  var raw = String(cwd)
  if (raw.length > 400) return null
  if (raw.charAt(0) === "/") return null
  var segments = raw.split("/")
  var clean = []
  for (var i = 0; i < segments.length; i++) {
    var seg = segments[i]
    if (seg === "" || seg === ".") continue
    if (seg === "..") return null
    clean.push(seg)
  }
  return clean.length === 0 ? base : (base + "/" + clean.join("/"))
}

function validateEntry(raw, projectPath, seenIds) {
  if (!raw || typeof raw !== "object") return { error: "entry is not an object" }
  if (!isNonEmptyString(raw.id, 64) || !ID_RE.test(raw.id)) {
    return { error: "id must match [a-zA-Z0-9_-]{1,64}" }
  }
  if (seenIds[raw.id]) return { error: "duplicate id \"" + raw.id + "\"" }
  if (!isNonEmptyString(raw.name, 80)) return { error: "name must be 1-80 characters" }
  if (!Array.isArray(raw.command) || raw.command.length === 0 || raw.command.length > 20) {
    return { error: "command must be a non-empty array of up to 20 strings" }
  }
  var command = []
  for (var i = 0; i < raw.command.length; i++) {
    if (!isNonEmptyString(raw.command[i], 200)) return { error: "command arguments must be 1-200 character strings" }
    command.push(raw.command[i])
  }
  var cwd = resolveCwd(projectPath, raw.cwd)
  if (cwd === null) return { error: "cwd must be a relative path inside the project directory" }
  var url = ""
  if (raw.url !== undefined && raw.url !== null && raw.url !== "") {
    if (!isNonEmptyString(raw.url, 2000) || !URL_RE.test(raw.url)) {
      return { error: "url must start with http:// or https://" }
    }
    url = raw.url
  }
  return {
    service: { id: raw.id, name: raw.name, command: command, cwd: cwd, url: url }
  }
}

// Parses and validates the contents of <projectPath>/.omaforge/services.json.
// Never throws; returns { services, skipped, error }.
function parseConfig(rawText, projectPath) {
  var text = String(rawText || "").trim()
  if (text === "") return { services: [], skipped: [], error: "" }

  var json
  try {
    json = JSON.parse(text)
  } catch (e) {
    return { services: [], skipped: [], error: "services.json is not valid JSON" }
  }
  if (!json || typeof json !== "object" || !Array.isArray(json.services)) {
    return { services: [], skipped: [], error: "services.json must contain a \"services\" array" }
  }

  var services = []
  var skipped = []
  var seenIds = {}
  for (var i = 0; i < json.services.length; i++) {
    if (services.length >= MAX_SERVICES) {
      skipped.push("more than " + MAX_SERVICES + " services configured; extra entries are hidden")
      break
    }
    var result = validateEntry(json.services[i], projectPath, seenIds)
    if (result.error) {
      skipped.push("entry " + i + ": " + result.error)
      continue
    }
    seenIds[result.service.id] = true
    services.push(result.service)
  }
  return { services: services, skipped: skipped, error: "" }
}
