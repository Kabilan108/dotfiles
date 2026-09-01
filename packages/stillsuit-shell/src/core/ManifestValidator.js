.pragma library

var kindToEntryPoint = {
    "bar": "bar",
    "bar-widget": "barWidget",
    "service": "service",
    "panel": "panel",
    "overlay": "overlay",
    "menu": "menu"
}

var allowedKinds = ["bar", "bar-widget", "service", "panel", "overlay", "menu"]
var allowedManifestKeys = [
    "schemaVersion",
    "id",
    "name",
    "description",
    "version",
    "apiVersion",
    "kinds",
    "entryPoints",
    "scope",
    "capabilities",
    "dependencies",
    "barWidget",
    "keepLoaded",
    "stateSchemaVersion"
]
var allowedEntryPointKeys = ["bar", "barWidget", "service", "panel", "overlay", "menu"]
var allowedScopeKeys = ["bar", "barWidget", "service", "panel", "overlay", "menu"]

function isPlainObject(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value)
}

function hasOnlyKeys(value, keys) {
    for (var key in value) {
        if (keys.indexOf(key) === -1)
            return false
    }
    return true
}

function uniqueStrings(value) {
    if (!Array.isArray(value))
        return false

    var seen = {}
    for (var index = 0; index < value.length; index++) {
        if (typeof value[index] !== "string" || seen[value[index]] === true)
            return false
        seen[value[index]] = true
    }
    return true
}

function pluginIdValid(value) {
    return typeof value === "string" && /^stillsuit(?:\.[a-z][a-z0-9-]*)+$/.test(value)
}

function entryPointValid(value) {
    if (typeof value !== "string" || value.length === 0 || value.charAt(0) === "/")
        return false
    if (value.indexOf("//") !== -1)
        return false
    return /^(?:[A-Za-z0-9][A-Za-z0-9._-]*\/)*[A-Za-z0-9][A-Za-z0-9._-]*\.qml$/.test(value)
}

function semanticVersionValid(value) {
    return typeof value === "string"
        && /^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$/.test(value)
}

function capabilityValid(value) {
    return typeof value === "string" && /^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/.test(value)
}

function validate(manifest) {
    var errors = []
    if (!isPlainObject(manifest))
        return ["manifest must be an object"]

    if (!hasOnlyKeys(manifest, allowedManifestKeys))
        errors.push("manifest contains an unknown field")
    if (manifest.schemaVersion !== 1)
        errors.push("schemaVersion must be 1")
    if (!pluginIdValid(manifest.id))
        errors.push("id does not match the Stillsuit plugin ID format")
    if (typeof manifest.name !== "string" || manifest.name.length < 1 || manifest.name.length > 80)
        errors.push("name must contain 1 to 80 characters")
    if (manifest.description !== undefined
            && (typeof manifest.description !== "string" || manifest.description.length > 500))
        errors.push("description must contain at most 500 characters")
    if (!semanticVersionValid(manifest.version))
        errors.push("version must be a semantic version")
    if (manifest.apiVersion !== "1")
        errors.push("apiVersion must be \"1\"")

    if (!uniqueStrings(manifest.kinds) || manifest.kinds.length === 0) {
        errors.push("kinds must be a non-empty array without duplicates")
    } else {
        for (var kindIndex = 0; kindIndex < manifest.kinds.length; kindIndex++) {
            if (allowedKinds.indexOf(manifest.kinds[kindIndex]) === -1)
                errors.push("unknown kind: " + manifest.kinds[kindIndex])
        }
    }

    if (!isPlainObject(manifest.entryPoints) || !hasOnlyKeys(manifest.entryPoints, allowedEntryPointKeys)) {
        errors.push("entryPoints must contain only known entry-point keys")
    } else {
        var entryPointCount = 0
        for (var entryPointKey in manifest.entryPoints) {
            entryPointCount++
            if (!entryPointValid(manifest.entryPoints[entryPointKey]))
                errors.push("invalid entry point for " + entryPointKey)
        }
        if (entryPointCount === 0)
            errors.push("entryPoints must not be empty")
    }

    if (!isPlainObject(manifest.scope) || !hasOnlyKeys(manifest.scope, allowedScopeKeys)) {
        errors.push("scope must contain only known contribution keys")
    } else if (Object.keys(manifest.scope).length === 0) {
        errors.push("scope must not be empty")
    }

    validateContributions(manifest, errors)
    validateScopes(manifest, errors)
    validateOptionalFields(manifest, errors)
    return errors
}

function validateContributions(manifest, errors) {
    if (Array.isArray(manifest.kinds) && isPlainObject(manifest.entryPoints)
            && isPlainObject(manifest.scope)) {
        for (var declaredIndex = 0; declaredIndex < manifest.kinds.length; declaredIndex++) {
            var declaredKind = manifest.kinds[declaredIndex]
            var contributionKey = kindToEntryPoint[declaredKind]
            if (!contributionKey)
                continue
            if (manifest.entryPoints[contributionKey] === undefined)
                errors.push("missing entry point for " + declaredKind)
            if (manifest.scope[contributionKey] === undefined)
                errors.push("missing scope for " + declaredKind)
        }
    }

    if (Array.isArray(manifest.kinds) && isPlainObject(manifest.entryPoints)) {
        for (var suppliedEntryPoint in manifest.entryPoints) {
            var suppliedKind = kindForEntryPoint(suppliedEntryPoint)
            if (manifest.kinds.indexOf(suppliedKind) === -1)
                errors.push("entry point does not match a declared kind: " + suppliedEntryPoint)
        }
    }
    if (Array.isArray(manifest.kinds) && isPlainObject(manifest.scope)) {
        for (var suppliedScope in manifest.scope) {
            var scopeKind = kindForEntryPoint(suppliedScope)
            if (manifest.kinds.indexOf(scopeKind) === -1)
                errors.push("scope does not match a declared kind: " + suppliedScope)
        }
    }
}

function validateScopes(manifest, errors) {
    if (!isPlainObject(manifest.scope))
        return

    if (manifest.scope.bar !== undefined && manifest.scope.bar !== "per-output")
        errors.push("bar scope must be per-output")
    if (manifest.scope.barWidget !== undefined && manifest.scope.barWidget !== "per-output")
        errors.push("barWidget scope must be per-output")
    if (manifest.scope.service !== undefined && manifest.scope.service !== "global")
        errors.push("service scope must be global")

    var routedKeys = ["panel", "overlay", "menu"]
    for (var index = 0; index < routedKeys.length; index++) {
        var key = routedKeys[index]
        if (manifest.scope[key] !== undefined
                && manifest.scope[key] !== "global"
                && manifest.scope[key] !== "per-output")
            errors.push(key + " scope must be global or per-output")
    }
}

function validateOptionalFields(manifest, errors) {
    if (manifest.capabilities !== undefined) {
        if (!uniqueStrings(manifest.capabilities)) {
            errors.push("capabilities must be a string array without duplicates")
        } else {
            for (var capabilityIndex = 0; capabilityIndex < manifest.capabilities.length; capabilityIndex++) {
                if (!capabilityValid(manifest.capabilities[capabilityIndex]))
                    errors.push("invalid capability: " + manifest.capabilities[capabilityIndex])
            }
        }
    }

    if (manifest.dependencies !== undefined) {
        if (!uniqueStrings(manifest.dependencies)) {
            errors.push("dependencies must be a string array without duplicates")
        } else {
            for (var dependencyIndex = 0; dependencyIndex < manifest.dependencies.length; dependencyIndex++) {
                if (!pluginIdValid(manifest.dependencies[dependencyIndex]))
                    errors.push("invalid dependency ID: " + manifest.dependencies[dependencyIndex])
            }
        }
    }

    if (manifest.barWidget !== undefined) {
        if (!isPlainObject(manifest.barWidget)
                || !hasOnlyKeys(manifest.barWidget, ["defaultSection", "allowMultiple"])) {
            errors.push("barWidget metadata contains an unknown field")
        } else {
            if (!Array.isArray(manifest.kinds) || manifest.kinds.indexOf("bar-widget") === -1)
                errors.push("barWidget metadata requires the bar-widget kind")
            if (manifest.barWidget.defaultSection !== undefined
                    && ["left", "center", "right"].indexOf(manifest.barWidget.defaultSection) === -1)
                errors.push("barWidget.defaultSection is invalid")
            if (manifest.barWidget.allowMultiple !== undefined
                    && typeof manifest.barWidget.allowMultiple !== "boolean")
                errors.push("barWidget.allowMultiple must be boolean")
        }
    }

    if (manifest.keepLoaded !== undefined) {
        if (typeof manifest.keepLoaded !== "boolean")
            errors.push("keepLoaded must be boolean")
        if (!Array.isArray(manifest.kinds)
                || !manifest.kinds.some(function(kind) {
                    return kind === "panel" || kind === "overlay" || kind === "menu"
                }))
            errors.push("keepLoaded requires a routed surface kind")
    }

    if (manifest.stateSchemaVersion !== undefined
            && (!Number.isInteger(manifest.stateSchemaVersion) || manifest.stateSchemaVersion < 1))
        errors.push("stateSchemaVersion must be a positive integer")
}

function kindForEntryPoint(key) {
    for (var kind in kindToEntryPoint) {
        if (kindToEntryPoint[kind] === key)
            return kind
    }
    return ""
}

function entryPointKey(kind) {
    return kindToEntryPoint[kind] || ""
}
