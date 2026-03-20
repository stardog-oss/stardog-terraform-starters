import base64
import json
import ssl
import urllib.error
import urllib.request
from typing import Iterable, Optional, Sequence, Set, Tuple

from stardog_common.permissions import (
    PermissionValidationError,
    api_resource_type,
    ensure_valid_action,
    ensure_valid_resource,
)

try:
    import stardog  # type: ignore
except ImportError as _exc:  # pragma: no cover - optional dependency
    stardog = None
    _STARDOG_IMPORT_ERROR = _exc
else:  # pragma: no cover
    _STARDOG_IMPORT_ERROR = None


Permission = Tuple[str, str]


class StardogAdminClient:
    """Small helper around the Stardog admin REST API (with optional pystardog support)."""

    def __init__(
        self,
        endpoint: str,
        username: str,
        password: str,
        *,
        verify_ssl: bool = True,
        timeout: int = 30,
    ) -> None:
        self.endpoint = endpoint.rstrip("/")
        self.username = username
        self.password = password
        self.verify_ssl = verify_ssl
        self.timeout = timeout
        if stardog is None:
            raise RuntimeError(
                "Stardog Python client (pystardog package) is required for StardogAdminClient "
                f"(import failed: {_STARDOG_IMPORT_ERROR})"
            )
        self._admin = None
        admin_kwargs = {
            "endpoint": self.endpoint,
            "username": self.username,
            "password": self.password,
        }
        if not self.verify_ssl:
            admin_kwargs["verify"] = False
        try:  # pragma: no cover - relies on external dependency
            self._admin = stardog.Admin(  # type: ignore[attr-defined]
                **admin_kwargs,
            )
        except TypeError as exc:  # pragma: no cover - fallback for older clients
            if "verify" in str(exc) and "unexpected" in str(exc):
                admin_kwargs.pop("verify", None)
                self._admin = stardog.Admin(  # type: ignore[attr-defined]
                    **admin_kwargs,
                )
            else:
                raise
        except Exception as exc:  # pragma: no cover
            raise RuntimeError(f"Failed to initialise Stardog admin client: {exc}") from exc

    # ------------- High-level operations -------------

    def ensure_role(self, role: str) -> None:
        roles = self.list_roles()
        if role in roles:
            return
        method = getattr(self._admin, "new_role", None)
        if not callable(method):
            raise RuntimeError("pystardog Admin client lacks new_role()")
        try:
            method(role)  # type: ignore[misc]
        except Exception as exc:  # pragma: no cover
            raise RuntimeError(f"Failed to create role '{role}': {exc}") from exc

    def delete_role(self, role: str) -> None:
        try:
            role_obj = self._admin.role(role)  # type: ignore[attr-defined]
        except Exception as exc:  # pragma: no cover
            message = str(exc).lower()
            if "does not exist" in message or "sernf2" in message or "404" in message:
                return
            raise RuntimeError(f"Failed to fetch role '{role}': {exc}") from exc

        delete_method = getattr(role_obj, "delete", None)
        if not callable(delete_method):
            raise RuntimeError("pystardog role object lacks delete()")
        try:
            delete_method()  # type: ignore[misc]
        except Exception as exc:  # pragma: no cover
            message = str(exc).lower()
            if "does not exist" in message or "sernf2" in message or "404" in message:
                return
            raise RuntimeError(f"Failed to delete role '{role}': {exc}") from exc

    def list_roles(self) -> Sequence[str]:
        try:
            roles = self._admin.roles()
        except Exception as exc:  # pragma: no cover
            raise RuntimeError(f"Failed to list roles: {exc}") from exc
        try:
            if isinstance(roles, dict) and "roles" in roles:
                value = roles["roles"]
            else:
                value = roles
            if isinstance(value, (list, tuple)):
                return [str(item) for item in value]
        except Exception as exc:  # pragma: no cover
            raise RuntimeError(f"Unexpected response listing roles: {exc}") from exc
        raise RuntimeError("Unexpected response listing roles")

    def get_role_permissions(self, role: str) -> Set[Permission]:
        try:
            role_obj = self._admin.role(role)  # type: ignore[attr-defined]
            raw_permissions = role_obj.permissions()  # type: ignore[attr-defined]
        except Exception as exc:  # pragma: no cover
            raise RuntimeError(f"Failed to fetch permissions for role '{role}': {exc}") from exc

        raw_permissions = _normalize_permissions(raw_permissions)
        normalized: Set[Permission] = set()
        for action, resource in raw_permissions:
            try:
                normalized_action = ensure_valid_action(action)
            except PermissionValidationError:
                continue
            try:
                normalized_resource = ensure_valid_resource(resource)
            except PermissionValidationError:
                normalized_resource = resource.strip()
            normalized.add((normalized_action, normalized_resource))
        return normalized

    def grant_role_permission(self, role: str, action: str, resource_type: str, resource: str) -> None:
        action_api = "*" if action.upper() == "ALL" else action.lower()
        resource_type_api = api_resource_type(resource_type)
        resource_api = "*" if resource == "*" else resource
        try:
            role_obj = self._admin.role(role)  # type: ignore[attr-defined]
            role_obj.add_permission(action_api, resource_type_api, resource_api)  # type: ignore[attr-defined]
        except Exception as exc:  # pragma: no cover
            raise RuntimeError(
                f"Failed to grant {action} on {resource_type}:{resource} to '{role}': {exc}"
            ) from exc

    def revoke_role_permission(self, role: str, action: str, resource_type: str, resource: str) -> None:
        action_api = "*" if action.upper() == "ALL" else action.lower()
        resource_type_api = api_resource_type(resource_type)
        resource_api = "*" if resource == "*" else resource
        try:
            role_obj = self._admin.role(role)  # type: ignore[attr-defined]
            role_obj.remove_permission(action_api, resource_type_api, resource_api)  # type: ignore[attr-defined]
        except Exception as exc:  # pragma: no cover
            raise RuntimeError(
                f"Failed to delete {action} on {resource_type}:{resource} from '{role}': {exc}"
            ) from exc

    # ------------- Low-level helpers -------------

    def _request(
        self,
        method: str,
        path: str,
        payload: Optional[dict] = None,
    ) -> Tuple[int, str, Optional[str]]:
        url = f"{self.endpoint}{path}"
        data = None
        headers = {
            "Accept": "application/json",
            "Authorization": f"Basic {self._basic_auth()}",
        }
        if payload is not None:
            data = json.dumps(payload).encode("utf-8")
            headers["Content-Type"] = "application/json"
        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        context = None
        if url.startswith("https://") and not self.verify_ssl:
            context = ssl._create_unverified_context()  # noqa: SLF001 - intentional
        try:
            with urllib.request.urlopen(req, context=context, timeout=self.timeout) as resp:
                return resp.status, resp.read().decode("utf-8"), None
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            return exc.code, body, body or str(exc)
        except urllib.error.URLError as exc:
            return 0, "", str(exc.reason)

    def _basic_auth(self) -> str:
        token = f"{self.username}:{self.password}".encode("utf-8")
        return base64.b64encode(token).decode("ascii")


def _normalize_permissions(raw: object) -> Set[Permission]:
    """Accept JSON text or already-parsed structures and return normalized permission tuples."""
    if isinstance(raw, str):
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            return set()
    else:
        data = raw

    if isinstance(data, dict):
        if "permissions" in data and isinstance(data["permissions"], list):
            entries = data["permissions"]
        else:
            entries = []
            for value in data.values():
                if isinstance(value, list):
                    entries.extend(value)
    elif isinstance(data, list):
        entries = data
    else:
        entries = []

    result: Set[Permission] = set()
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        actions = entry.get("actions") or entry.get("action")
        resources = entry.get("resources") or entry.get("resource")
        action_values = _coerce_to_strings(actions)
        resource_values = _coerce_resource_values(resources)
        for action in action_values:
            action_norm = action.lower().strip()
            if not action_norm:
                continue
            for resource in resource_values:
                resource_norm = resource.strip()
                if resource_norm:
                    result.add((action_norm, resource_norm))
    return result


def _coerce_to_strings(value: object) -> Iterable[str]:
    if value is None:
        return []
    if isinstance(value, (list, tuple, set)):
        return [str(v) for v in value]
    return [str(value)]


def _coerce_resource_values(value: object) -> Iterable[str]:
    if value is None:
        return []
    if isinstance(value, (list, tuple, set)):
        result = []
        for v in value:
            norm = _normalize_resource(v)
            if norm:
                result.append(norm)
        return result
    norm = _normalize_resource(value)
    return [norm] if norm else []


def _normalize_resource(value: object) -> Optional[str]:
    if isinstance(value, dict):
        if "value" in value:
            return str(value["value"])
        rtype = value.get("type") or value.get("resourceType")
        rname = value.get("name") or value.get("resourceName") or value.get("resource")
        if rtype is not None and rname is not None:
            return f"{rtype}:{rname}"
    elif isinstance(value, str):
        return value
    return None


def _quote(value: str) -> str:
    from urllib.parse import quote  # Local import to avoid top-level dependency if unused

    return quote(value, safe="")
