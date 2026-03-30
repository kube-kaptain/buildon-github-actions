# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
SPEC_VALIDATE_DEFAULTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPEC_JSON_SCHEMA_URL="${SPEC_JSON_SCHEMA_URL:-${SPEC_VALIDATE_DEFAULTS_DIR}/../../schemas/json-schema-draft-2020-12.json}"
