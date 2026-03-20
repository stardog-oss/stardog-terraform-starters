from __future__ import annotations

from dataclasses import dataclass


ALLOWED_ACTIONS = {
    "read",
    "write",
    "create",
    "delete",
    "revoke",
    "grant",
    "execute",
    "all",
}

_RESOURCE_TYPE_CANONICAL = {
    "all": "all",
    "*": "all",
    "user": "user",
    "role": "role",
    "role_assignment": "role_assignment",
    "permission": "permission",
    "database": "db",
    "db": "db",
    "named_graph": "named_graph",
    "namedgraph": "named_graph",
    "data_source": "data_source",
    "datasource": "data_source",
    "virtual_graph": "virtual_graph",
    "virtualgraph": "virtual_graph",
    "dbms_admin": "dbms_admin",
    "dbmsadmin": "dbms_admin",
    "admin": "dbms_admin",
    "database_metadata": "metadata",
    "metadata": "metadata",
    "db_metadata": "metadata",
    "database_admin": "database_admin",
    "databaseadmin": "database_admin",
    "db_admin": "database_admin",
    "stored_query": "stored_query",
    "storedquery": "stored_query",
    "cache": "cache",
    "cache_target": "cache_target",
    "cachetarget": "cache_target",
    "sensitive_properties": "sensitive_properties",
    "sensitiveproperties": "sensitive_properties",
    "entity_resolution": "entity_resolution",
    "entityresolution": "entity_resolution",
}

_RESOURCE_TYPE_API_VALUE = {
    "all": "*",
    "db": "db",
    "role_assignment": "role-assignment",
    "named_graph": "named-graph",
    "data_source": "data-source",
    "virtual_graph": "virtual-graph",
    "dbms_admin": "dbms-admin",
    "metadata": "metadata",
    "database_admin": "database-admin",
    "stored_query": "stored-query",
    "cache_target": "cache-target",
    "sensitive_properties": "sensitive-properties",
    "entity_resolution": "entity-resolution",
}

class PermissionValidationError(ValueError):
    """Raised when a supplied action or resource is invalid."""


def normalize_action(value: str) -> str:
    return value.strip().lower()


def ensure_valid_action(value: str) -> str:
    normalized = normalize_action(value)
    if normalized not in ALLOWED_ACTIONS:
        allowed = ", ".join(sorted(ALLOWED_ACTIONS))
        raise PermissionValidationError(f"action '{value}' must be one of: {allowed}")
    return normalized


def _sanitize_resource_type(value: str) -> str:
    return value.strip().replace("-", "_").lower()


def canonical_resource_type(value: str) -> str | None:
    key = _sanitize_resource_type(value)
    return _RESOURCE_TYPE_CANONICAL.get(key)


def api_resource_type(value: str) -> str:
    canonical = canonical_resource_type(value) or _sanitize_resource_type(value)
    return _RESOURCE_TYPE_API_VALUE.get(canonical, canonical.lower())


def ensure_valid_resource(value: str) -> str:
    trimmed = value.strip()
    if trimmed in {"*:*", "*.*"}:
        return trimmed
    if ":" not in trimmed:
        raise PermissionValidationError("resource must be '<type>:<name>' or a wildcard (*.* or *:*)")
    parts = trimmed.split(":", 1)
    if len(parts) != 2:
        raise PermissionValidationError("resource must contain a single ':' separating type and name")
    rtype, name = parts[0].strip(), parts[1].strip()
    if not rtype or not name:
        raise PermissionValidationError("resource type and name must be non-empty")
    canonical = canonical_resource_type(rtype)
    if canonical is None:
        allowed = ", ".join(sorted(set(_RESOURCE_TYPE_CANONICAL.values())))
        raise PermissionValidationError(f"resource type '{rtype}' is not supported (allowed: {allowed})")
    return f"{canonical}:{name}"


def canonical_resource_key(resource: str) -> str:
    normalized = ensure_valid_resource(resource)
    if normalized in {"*:*", "*.*"}:
        return normalized
    rtype, name = normalized.split(":", 1)
    canonical = canonical_resource_type(rtype) or _sanitize_resource_type(rtype)
    return f"{canonical}:{name.strip()}"


@dataclass(frozen=True)
class PermissionKey:
    action: str
    resource: str


def canonical_permission_key(action: str, resource: str) -> PermissionKey:
    return PermissionKey(
        action=ensure_valid_action(action),
        resource=canonical_resource_key(resource),
    )
