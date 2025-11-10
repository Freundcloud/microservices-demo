# ServiceNow DevOps Tables Reference

**Source**: [sys_db_object.json](sys_db_object.json)
**Last Updated**: 2025-11-06

This document provides a quick reference for all ServiceNow DevOps tables available in the instance.

---

## Software Quality Tables

Used for SBOM, dependency scanning, and code quality metrics:

| Table Name | Label | Purpose |
|------------|-------|---------|
| `sn_devops_software_quality_scan_summary` | Software Quality Scan Summary | High-level scan results (SBOM, SAST, etc.) |
| `sn_devops_software_quality_scan_detail` | Software Quality Scan Detail | Individual findings/components |
| `sn_devops_software_quality_category_detail` | Software Quality Category Detail | Category-level aggregation |
| `sn_devops_software_quality_category` | Software Quality Category | Quality categories definition |
| `sn_devops_software_quality_sub_category` | Software Quality Sub Category | Sub-category definitions |
| `sn_devops_software_quality_scan_summary_relations` | Software Quality Scan Summary Relations | Relations between scans |

**Primary Use**: Upload SBOM scan results (Issue #73)

---

## Test Result Tables

Used for unit tests, integration tests, and test reporting:

| Table Name | Label | Purpose |
|------------|-------|---------|
| `sn_devops_test_summary` | Test Summary | Aggregate test results per pipeline execution |
| `sn_devops_test_result` | Test Result | Individual test case results |
| `sn_devops_test_summary_relations` | Test Summary Relations | Relations between test summaries |
| `sn_devops_test_execution` | Test Execution | Test execution details |
| `sn_devops_test_type` | Test Type | Test type definitions (unit, integration, e2e) |
| `sn_devops_test_type_mapping` | Test Type Mapping | Mapping test types to results |
| `sn_devops_build_test_summary` | Build Test Summary | Build-specific test summaries |
| `sn_devops_build_test_result` | Build Test Result | Build-specific test results |

**Current Usage**: Test results uploaded via ServiceNow DevOps Actions

---

## Performance Test Tables

Used for smoke tests, load tests, and performance metrics:

| Table Name | Label | Purpose |
|------------|-------|---------|
| `sn_devops_performance_test_summary` | Performance test summary | Performance/smoke test results |

**Planned Use**: Upload smoke test results (Issue #72)

---

## Related Documentation

- [SERVICENOW-SBOM-SOFTWARE-QUALITY-INTEGRATION-ANALYSIS.md](SERVICENOW-SBOM-SOFTWARE-QUALITY-INTEGRATION-ANALYSIS.md) - SBOM upload implementation
- [SERVICENOW-SMOKE-TEST-INTEGRATION-ANALYSIS.md](SERVICENOW-SMOKE-TEST-INTEGRATION-ANALYSIS.md) - Smoke test upload implementation
- [SERVICENOW-TOOL-ID-FIX.md](SERVICENOW-TOOL-ID-FIX.md) - Tool ID consistency fix

---

**Source Data**: Complete table list from ServiceNow sys_db_object API (docs/sys_db_object.json).
