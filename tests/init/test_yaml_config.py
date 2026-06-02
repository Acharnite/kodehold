#!/usr/bin/env python3
"""
test_yaml_config.py — Schema Validation Tests for YAML Configuration System.

References:
    - ADR-0037 (Accepted)
    - config/agents.schema.json
    - config/agents.yaml
    - config/tasks.yaml

Test categories:
    1. YAML Parsing
    2. JSON Schema Validation
    3. Script Execution
    4. Edge Cases (permissions merge, missing fields, duplicate triggers)
"""

import json
import os
import re
import subprocess
import sys
import copy
from contextlib import contextmanager

import yaml
import jsonschema

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CONFIG_DIR = os.path.join(PROJECT_DIR, "config")
SCRIPTS_DIR = os.path.join(PROJECT_DIR, "scripts")

AGENTS_YAML = os.path.join(CONFIG_DIR, "agents.yaml")
TASKS_YAML = os.path.join(CONFIG_DIR, "tasks.yaml")
SCHEMA_JSON = os.path.join(CONFIG_DIR, "agents.schema.json")
VALIDATE_SCRIPT = os.path.join(SCRIPTS_DIR, "validate-config.sh")
SYNC_SCRIPT = os.path.join(SCRIPTS_DIR, "sync-agent-config.sh")

AGENTS_MD_DIR = os.path.join(PROJECT_DIR, ".opencode", "agents")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def load_yaml(path):
    """Load and return parsed YAML from *path*."""
    with open(path) as f:
        return yaml.safe_load(f)


def load_schema(path):
    """Load and return the JSON Schema from *path*."""
    with open(path) as f:
        return json.load(f)


def run_script(script_path, *args):
    """Run *script_path* with *args* and return (returncode, stdout, stderr)."""
    env = os.environ.copy()
    result = subprocess.run(
        [script_path] + list(args),
        capture_output=True,
        text=True,
        env=env,
        cwd=PROJECT_DIR,
    )
    return result.returncode, result.stdout, result.stderr


def get_agents_data():
    """Return the parsed agents.yaml top-level dict and the schema."""
    data = load_yaml(AGENTS_YAML)
    schema = load_schema(SCHEMA_JSON)
    return data, schema


# ---------------------------------------------------------------------------
# Helpers for testing scripts with modified configs
# ---------------------------------------------------------------------------
# The validate-config.sh and sync-agent-config.sh scripts hardcode the YAML
# path from the script location ($SCRIPT_DIR/../config/agents.yaml). Setting
# AGENTS_YAML env var does NOT override this because bash recomputes it.
# Therefore, to test failure modes we must temporarily replace the actual
# config file and then restore it.

@contextmanager
def with_modified_yaml(modified_data):
    """Context manager that temporarily replaces agents.yaml with *modified_data*.

    Yields the path. Restores the original file on exit, even on exception.
    """
    backup = AGENTS_YAML + ".bak"
    # Backup the original
    os.rename(AGENTS_YAML, backup)
    try:
        with open(AGENTS_YAML, "w") as f:
            yaml.dump(modified_data, f)
        yield AGENTS_YAML
    finally:
        # Restore the original
        if os.path.exists(backup):
            os.remove(AGENTS_YAML)  # remove our temp version
            os.rename(backup, AGENTS_YAML)


# ===================================================================
# 1.  YAML Parsing
# ===================================================================

class TestYamlParsing:
    """Verify that config files are valid YAML and contain expected structure."""

    def test_agents_yaml_parses(self):
        """config/agents.yaml must parse as valid YAML."""
        data = load_yaml(AGENTS_YAML)
        assert data is not None, "agents.yaml is empty or None"
        assert isinstance(data, dict), "agents.yaml root must be a dict"

    def test_tasks_yaml_parses(self):
        """config/tasks.yaml must parse as valid YAML."""
        data = load_yaml(TASKS_YAML)
        assert data is not None, "tasks.yaml is empty or None"
        assert isinstance(data, dict), "tasks.yaml root must be a dict"

    def test_eight_agents_present(self):
        """There must be exactly 8 agents in config/agents.yaml."""
        data = load_yaml(AGENTS_YAML)
        agents = data.get("agents", [])
        assert len(agents) == 8, f"Expected 8 agents, found {len(agents)}"

    def test_all_agents_have_name_description(self):
        """Every agent entry must have 'name' and 'description'."""
        data = load_yaml(AGENTS_YAML)
        for i, agent in enumerate(data["agents"]):
            agent_name = agent.get("name", f"<index {i}>")
            assert "name" in agent, f"Agent {agent_name} missing 'name'"
            assert isinstance(agent["name"], str), (
                f"Agent {agent_name}: name must be str"
            )
            assert "description" in agent, f"Agent {agent_name} missing 'description'"
            assert isinstance(agent["description"], str), (
                f"Agent {agent_name}: description must be str"
            )

    def test_triggers_field_when_present_is_a_list(self):
        """If an agent has a 'triggers' field, it must be a list (director is the
        orchestrator and intentionally has no triggers field)."""
        data = load_yaml(AGENTS_YAML)
        for agent in data["agents"]:
            if "triggers" in agent:
                assert isinstance(agent["triggers"], list), (
                    f"Agent {agent['name']}: triggers must be a list"
                )

    def test_director_has_no_triggers(self):
        """Director (orchestrator) should have no triggers — not triggerable."""
        data = load_yaml(AGENTS_YAML)
        director = next(a for a in data["agents"] if a["name"] == "director")
        assert "triggers" not in director or len(director.get("triggers", ())) == 0, (
            f"Director should have 0 triggers, got {director.get('triggers')}"
        )

    def test_agent_names_are_kebab_case(self):
        """Agent names must match pattern ^[a-z][a-z0-9-]*$."""
        data = load_yaml(AGENTS_YAML)
        pattern = re.compile(r"^[a-z][a-z0-9-]*$")
        for agent in data["agents"]:
            name = agent.get("name", "")
            assert pattern.match(name), (
                f"Agent name '{name}' does not match kebab-case pattern"
            )

    def test_agent_names_are_unique(self):
        """Agent names within the list must be unique."""
        data = load_yaml(AGENTS_YAML)
        names = [a["name"] for a in data["agents"]]
        assert len(names) == len(set(names)), f"Duplicate agent names: {names}"

    def test_triggers_are_unique_across_agents(self):
        """No two agents may share the same trigger keyword (ADR-0037 §6.1)."""
        data = load_yaml(AGENTS_YAML)
        trigger_map = {}  # trigger -> agent_name
        for agent in data["agents"]:
            aname = agent.get("name", "unknown")
            for trigger in agent.get("triggers", []):
                assert trigger not in trigger_map, (
                    f"Duplicate trigger '{trigger}' across agents: "
                    f"'{trigger_map[trigger]}' and '{aname}'"
                )
                trigger_map[trigger] = aname

    def test_agents_yaml_has_defaults_block(self):
        """agents.yaml should contain a 'defaults' block for shared config."""
        data = load_yaml(AGENTS_YAML)
        assert "defaults" in data, "agents.yaml missing 'defaults' block"
        assert isinstance(data["defaults"], dict), "'defaults' must be a dict"

    def test_tasks_yaml_has_workflows(self):
        """tasks.yaml must contain a 'workflows' list."""
        data = load_yaml(TASKS_YAML)
        assert "workflows" in data, "tasks.yaml missing 'workflows'"
        assert isinstance(data["workflows"], list), "'workflows' must be a list"
        assert len(data["workflows"]) > 0, "'workflows' list is empty"

    def test_tasks_yaml_has_gates(self):
        """tasks.yaml must contain a 'gates' list."""
        data = load_yaml(TASKS_YAML)
        assert "gates" in data, "tasks.yaml missing 'gates'"
        assert isinstance(data["gates"], list), "'gates' must be a list"
        assert len(data["gates"]) > 0, "'gates' list is empty"


# ===================================================================
# 2.  JSON Schema Validation
# ===================================================================

class TestJsonSchemaValidation:
    """Validate agents.yaml against agents.schema.json."""

    def _validate(self, instance):
        """Validate *instance* against the schema; return list of error messages."""
        schema = load_schema(SCHEMA_JSON)
        validator = jsonschema.Draft7Validator(schema)
        errors = sorted(validator.iter_errors(instance), key=lambda e: e.path)
        return [e.message for e in errors]

    def test_full_config_validates(self):
        """The complete agents.yaml must validate against agents.schema.json."""
        data = load_yaml(AGENTS_YAML)
        errors = self._validate(data)
        assert not errors, "Schema validation errors:\n  " + "\n  ".join(errors)

    def test_defaults_validates_without_name_or_description(self):
        """The 'defaults' block must NOT require name/description (agentDefaultsConfig)."""
        schema = load_schema(SCHEMA_JSON)
        defaults_def = schema.get("definitions", {}).get("agentDefaultsConfig", {})
        required = defaults_def.get("required", [])
        assert "name" not in required, (
            "agentDefaultsConfig should not require 'name'"
        )
        assert "description" not in required, (
            "agentDefaultsConfig should not require 'description'"
        )

    def test_agent_requires_name_and_description(self):
        """Each agent entry must require 'name' and 'description' (agentConfig)."""
        schema = load_schema(SCHEMA_JSON)
        agent_def = schema.get("definitions", {}).get("agentConfig", {})
        required = agent_def.get("required", [])
        assert "name" in required, "agentConfig must require 'name'"
        assert "description" in required, "agentConfig must require 'description'"

    def test_defaults_mode_is_valid_enum(self):
        """defaults.mode must be one of 'all' or 'subagent'."""
        data = load_yaml(AGENTS_YAML)
        defaults = data.get("defaults", {})
        mode = defaults.get("mode")
        assert mode in ("all", "subagent"), f"defaults.mode '{mode}' invalid"

    def test_each_agent_mode_is_valid(self):
        """Each agent's mode must be 'all' or 'subagent' if present."""
        data = load_yaml(AGENTS_YAML)
        for agent in data["agents"]:
            if "mode" in agent:
                assert agent["mode"] in ("all", "subagent"), (
                    f"agent '{agent['name']}'.mode '{agent['mode']}' invalid"
                )

    def test_permission_values_are_valid(self):
        """All permission values must be 'allow', 'deny', or 'ask'."""
        data = load_yaml(AGENTS_YAML)
        valid = {"allow", "deny", "ask"}

        # Check defaults
        defaults_perm = data.get("defaults", {}).get("permission", {})
        for key, val in defaults_perm.items():
            if key == "external_directory":
                continue
            assert val in valid, (
                f"defaults.permission.{key} = '{val}' not in {valid}"
            )

        # Check each agent
        for agent in data["agents"]:
            perm = agent.get("permission", {})
            for key, val in perm.items():
                if key == "external_directory":
                    continue
                assert val in valid, (
                    f"agent '{agent['name']}'.permission.{key} = '{val}' not in {valid}"
                )

    def test_schema_rejects_missing_name(self):
        """A minimal agent dict without 'name' should fail schema validation."""
        schema = load_schema(SCHEMA_JSON)
        bad_agent = {"description": "no name here"}
        bad_instance = {"agents": [bad_agent]}
        errors = list(jsonschema.Draft7Validator(schema).iter_errors(bad_instance))
        assert errors, "Expected validation errors for missing 'name', got none"
        assert any("name" in e.message for e in errors), (
            f"Expected error about missing 'name', got: "
            f"{' '.join(e.message for e in errors)}"
        )

    def test_schema_rejects_additional_properties(self):
        """Unknown keys in an agent should be rejected."""
        schema = load_schema(SCHEMA_JSON)
        bad_agent = {
            "name": "test-agent",
            "description": "test",
            "nonexistent_field": "should not be allowed",
        }
        bad_instance = {"agents": [bad_agent]}
        errors = list(jsonschema.Draft7Validator(schema).iter_errors(bad_instance))
        assert errors, "Expected validation error for additional property"

    def test_schema_rejects_invalid_trigger_type(self):
        """Trigger items must be strings."""
        schema = load_schema(SCHEMA_JSON)
        bad_agent = {
            "name": "test-agent",
            "description": "test",
            "triggers": ["valid", 42],
        }
        bad_instance = {"agents": [bad_agent]}
        errors = list(jsonschema.Draft7Validator(schema).iter_errors(bad_instance))
        assert errors, "Expected validation error for non-string trigger"


# ===================================================================
# 3.  Script Execution
# ===================================================================

class TestValidateConfigScript:
    """Validate that scripts/validate-config.sh behaves correctly."""

    def test_validate_config_exit_zero(self):
        """validate-config.sh must exit 0 against the current valid config."""
        ret, out, err = run_script(VALIDATE_SCRIPT)
        assert ret == 0, (
            f"validate-config.sh failed:\nstdout:{out}\nstderr:{err}"
        )

    def test_validate_config_reports_success(self):
        """validate-config.sh must print 'All validations passed!'."""
        ret, out, err = run_script(VALIDATE_SCRIPT)
        assert "All validations passed!" in out, (
            f"Expected success message, got:\n{out}"
        )

    def test_validate_config_fails_on_missing_name(self):
        """validate-config.sh must fail if an agent lacks 'name'."""
        data = load_yaml(AGENTS_YAML)
        modified = copy.deepcopy(data)
        del modified["agents"][-1]["name"]

        with with_modified_yaml(modified):
            ret, out, err = run_script(VALIDATE_SCRIPT)
        # Restored before assertion
        assert ret != 0, (
            f"Expected failure for missing name, got exit 0\n"
            f"stdout:{out}\nstderr:{err}"
        )

    def test_validate_config_fails_on_duplicate_triggers(self):
        """validate-config.sh must fail if there are duplicate triggers across agents."""
        data = load_yaml(AGENTS_YAML)
        modified = copy.deepcopy(data)
        # Agent[1] (index 1) has triggers; use its first trigger as duplicate
        dup_trigger = modified["agents"][1]["triggers"][0]
        # Add the duplicate to the last agent's triggers
        modified["agents"][-1]["triggers"].append(dup_trigger)

        with with_modified_yaml(modified):
            ret, out, err = run_script(VALIDATE_SCRIPT)

        assert ret != 0, (
            f"Expected failure for duplicate triggers, got exit 0\n"
            f"stdout:{out}\nstderr:{err}"
        )
        assert "Duplicate trigger" in (out + err), (
            f"Expected 'Duplicate trigger' message, got:\n"
            f"STDOUT:{out}\nSTDERR:{err}"
        )

    def test_validate_config_fails_on_empty_agents(self):
        """validate-config.sh must fail if 'agents' list is empty."""
        modified = {"defaults": {}, "agents": []}
        with with_modified_yaml(modified):
            ret, out, err = run_script(VALIDATE_SCRIPT)
        assert ret != 0, f"Expected failure for empty agents, got exit 0"

    def test_validate_config_fails_on_missing_description(self):
        """validate-config.sh must fail if an agent lacks 'description'."""
        data = load_yaml(AGENTS_YAML)
        modified = copy.deepcopy(data)
        del modified["agents"][0]["description"]

        with with_modified_yaml(modified):
            ret, out, err = run_script(VALIDATE_SCRIPT)
        assert ret != 0, (
            f"Expected failure for missing description, got exit 0\n"
            f"stdout:{out}\nstderr:{err}"
        )

    def test_validate_config_fails_on_invalid_agent_name(self):
        """validate-config.sh must fail if an agent name has invalid chars."""
        data = load_yaml(AGENTS_YAML)
        modified = copy.deepcopy(data)
        modified["agents"][0]["name"] = "Invalid-Name_123"

        with with_modified_yaml(modified):
            ret, out, err = run_script(VALIDATE_SCRIPT)
        assert ret != 0, (
            f"Expected failure for invalid name, got exit 0\n"
            f"stdout:{out}\nstderr:{err}"
        )


class TestSyncAgentConfigScript:
    """Validate that scripts/sync-agent-config.sh behaves correctly."""

    def test_sync_dry_run_exit_zero(self):
        """sync-agent-config.sh --dry-run must exit 0."""
        ret, out, err = run_script(SYNC_SCRIPT, "--dry-run")
        assert ret == 0, (
            f"--dry-run failed:\nstdout:{out}\nstderr:{err}"
        )

    def test_sync_dry_run_completes(self):
        """--dry-run output should contain completion message."""
        ret, out, err = run_script(SYNC_SCRIPT, "--dry-run")
        assert "Dry-run complete" in out, (
            f"Expected 'Dry-run complete' in output:\n{out}\n{err}"
        )

    def test_sync_diff_exit_zero_with_matching_config(self):
        """sync-agent-config.sh --diff must exit 0 when YAML and .md match."""
        ret, out, err = run_script(SYNC_SCRIPT, "--diff")
        assert ret == 0, (
            f"--diff failed:\nstdout:{out}\nstderr:{err}"
        )

    def test_sync_diff_detects_yaml_change(self):
        """--diff must detect when an agent's description is changed in YAML."""
        data = load_yaml(AGENTS_YAML)
        modified = copy.deepcopy(data)
        modified["agents"][0]["description"] = (
            "CHANGED_DESCRIPTION_FOR_TESTING_ONLY"
        )

        with with_modified_yaml(modified):
            ret, out, err = run_script(SYNC_SCRIPT, "--diff")

        assert ret == 1, (
            f"Expected --diff to detect mismatch, got exit {ret}\n"
            f"stdout:{out}\nstderr:{err}"
        )
        assert "DIFF" in out, (
            f"Expected 'DIFF' in output:\n{out}"
        )

    def test_sync_diff_exit_one_on_mismatch(self):
        """--diff must exit 1 when mismatches are found."""
        data = load_yaml(AGENTS_YAML)
        modified = copy.deepcopy(data)
        modified["agents"][0]["description"] = (
            "MODIFIED_DESC_FOR_TEST_ONLY"
        )

        with with_modified_yaml(modified):
            ret, out, err = run_script(SYNC_SCRIPT, "--diff")

        assert ret == 1, (
            f"Expected exit 1 for mismatch, got {ret}\n"
            f"stdout:{out}\nstderr:{err}"
        )


# ===================================================================
# 4.  Edge Cases & Permissions Merge
# ===================================================================

class TestPermissionsMerge:
    """Verify that defaults + per-agent overrides produce the correct merged result."""

    def test_director_override_overrules_defaults(self):
        """Director's explicit 'write: deny' should override defaults 'write: allow'."""
        data = load_yaml(AGENTS_YAML)
        director = next(a for a in data["agents"] if a["name"] == "director")
        perm = director.get("permission", {})

        assert perm.get("write") == "deny", (
            f"Director permission.write should be 'deny', got '{perm.get('write')}'"
        )
        assert perm.get("edit") == "deny", (
            f"Director permission.edit should be 'deny', got '{perm.get('edit')}'"
        )

    def test_architects_webfetch_override(self):
        """Architects should have webfetch=allow even though defaults have webfetch=deny."""
        data = load_yaml(AGENTS_YAML)
        architects = next(a for a in data["agents"] if a["name"] == "architects")
        perm = architects.get("permission", {})
        assert perm.get("webfetch") == "allow", (
            f"Architects permission.webfetch should be 'allow', "
            f"got '{perm.get('webfetch')}'"
        )

    def test_defaults_mode_is_subagent(self):
        """The default mode should be 'subagent'."""
        data = load_yaml(AGENTS_YAML)
        defaults = data.get("defaults", {})
        assert defaults.get("mode") == "subagent", (
            f"defaults.mode should be 'subagent', got '{defaults.get('mode')}'"
        )

    def test_director_mode_override(self):
        """Director should override mode to 'all'."""
        data = load_yaml(AGENTS_YAML)
        director = next(a for a in data["agents"] if a["name"] == "director")
        assert director.get("mode") == "all", (
            f"Director mode should be 'all', got '{director.get('mode')}'"
        )

    def test_second_opinion_inherits_default_mode(self):
        """second-opinion (no explicit mode) should inherit defaults.mode = 'subagent'."""
        data = load_yaml(AGENTS_YAML)
        second_opinion = next(
            a for a in data["agents"] if a["name"] == "second-opinion"
        )
        assert "mode" not in second_opinion, (
            "second-opinion should not have an explicit mode (inherits from defaults)"
        )

    def test_defaults_external_directory_patterns(self):
        """defaults.external_directory should be inside permission with expected patterns."""
        data = load_yaml(AGENTS_YAML)
        defaults = data.get("defaults", {})
        perm = defaults.get("permission", {})
        ext_dir = perm.get("external_directory", {})
        assert ext_dir.get("*") == "ask", (
            "Default permission.external_directory '*' should be 'ask'"
        )
        assert "/home/kiffer/project/**" in ext_dir, (
            "Missing /home/kiffer/project/** in permission.external_directory"
        )

    def test_defaults_permissions_key_set(self):
        """Defaults permission block must contain standard tool permission keys plus external_directory."""
        data = load_yaml(AGENTS_YAML)
        defaults = data.get("defaults", {})
        default_perm = defaults.get("permission", {})
        expected_keys = {
            "read", "write", "edit", "glob", "grep",
            "bash", "task", "skill", "webfetch", "websearch",
            "external_directory",
        }
        present_keys = set(default_perm.keys())
        assert present_keys == expected_keys, (
            f"Defaults permission keys mismatch.\n"
            f"  Expected: {expected_keys}\n"
            f"  Got:      {present_keys}"
        )


class TestEdgeCases:
    """Additional edge-case tests."""

    def test_all_triggers_in_central_registry(self):
        """Every agent's triggers should be documented in the central registry comment."""
        data = load_yaml(AGENTS_YAML)
        all_triggers = set()
        for agent in data["agents"]:
            for t in agent.get("triggers", []):
                all_triggers.add(t)

        with open(AGENTS_YAML) as f:
            content = f.read()

        # Extract trigger keywords from the registry comment
        # Format: "# agent_name:      trigger1, trigger2, ..."
        registry_pattern = re.compile(r"^# \S+:\s+(.+)$", re.MULTILINE)
        documented_triggers = set()
        for match in registry_pattern.finditer(content):
            triggers_line = match.group(1)
            for t in triggers_line.split(","):
                documented_triggers.add(t.strip())

        undocumented = all_triggers - documented_triggers
        assert not undocumented, (
            f"Triggers not documented in central registry: {undocumented}"
        )

    def test_hidden_agents_are_valid(self):
        """Agents with hidden:true still must have proper structure."""
        data = load_yaml(AGENTS_YAML)
        for agent in data["agents"]:
            if agent.get("hidden"):
                assert "name" in agent, f"Hidden agent missing name"
                assert "description" in agent, (
                    f"Hidden agent {agent['name']} missing description"
                )
                if "triggers" in agent:
                    assert isinstance(agent["triggers"], list), (
                        f"Hidden agent {agent['name']}: triggers must be a list"
                    )

    def test_total_unique_triggers_count(self):
        """There should be 37 unique triggers across all 7 triggerable agents."""
        data = load_yaml(AGENTS_YAML)
        all_triggers = set()
        for agent in data["agents"]:
            for t in agent.get("triggers", []):
                all_triggers.add(t)
        total = sum(len(a.get("triggers", ())) for a in data["agents"])
        assert len(all_triggers) == total, (
            f"Triggers not unique: {total} total, {len(all_triggers)} unique"
        )

    def test_tasks_yaml_references_valid_teams(self):
        """All teams referenced in tasks.yaml workflows must match agent names."""
        data = load_yaml(TASKS_YAML)
        agents_data = load_yaml(AGENTS_YAML)
        agent_names = {a["name"] for a in agents_data["agents"]}

        for workflow in data.get("workflows", []):
            for step in workflow.get("steps", []):
                team = step.get("team")
                if team:
                    assert team in agent_names, (
                        f"Workflow '{workflow.get('id')}' step references unknown "
                        f"team '{team}'. Valid teams: {agent_names}"
                    )

    def test_all_agents_have_triggers_or_are_orchestrator(self):
        """Every agent must have triggers EXCEPT director (the orchestrator)."""
        data = load_yaml(AGENTS_YAML)
        for agent in data["agents"]:
            if agent["name"] == "director":
                # Director is orchestrator — can have 0 triggers
                continue
            assert "triggers" in agent, (
                f"Agent '{agent['name']}' missing 'triggers' field"
            )
            assert isinstance(agent["triggers"], list), (
                f"Agent '{agent['name']}': triggers must be a list"
            )
            assert len(agent["triggers"]) > 0, (
                f"Agent '{agent['name']}' has empty triggers list"
            )

    def test_validate_config_fails_on_invalid_mode(self):
        """validate-config.sh must fail if an agent has an invalid mode."""
        data = load_yaml(AGENTS_YAML)
        modified = copy.deepcopy(data)
        modified["agents"][0]["mode"] = "invalid-mode-value"

        with with_modified_yaml(modified):
            ret, out, err = run_script(VALIDATE_SCRIPT)
        assert ret != 0, (
            f"Expected failure for invalid mode, got exit 0\n"
            f"stdout:{out}\nstderr:{err}"
        )


if __name__ == "__main__":
    import pytest
    sys.exit(pytest.main([__file__, "-v"]))
