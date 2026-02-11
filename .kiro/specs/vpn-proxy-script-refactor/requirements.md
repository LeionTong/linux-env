# VPN Proxy Script Refactor - Requirements

## Overview
Refactor the existing VPN/proxy management script to improve code quality, maintainability, and robustness while preserving all existing functionality.

## User Stories

### 1. As a developer maintaining this script, I want clear separation of concerns so that I can easily understand and modify specific functionality

**Acceptance Criteria:**
- 1.1 Configuration management is separated from business logic
- 1.2 Service operations (VPN, proxy, DNS) are modularized into distinct functions
- 1.3 Each function has a single, well-defined responsibility
- 1.4 Related functions are grouped logically

### 2. As a user of this script, I want robust error handling so that failures are clear and the system state remains consistent

**Acceptance Criteria:**
- 2.1 All external commands have proper error checking
- 2.2 Failed operations provide actionable error messages
- 2.3 Partial failures don't leave services in inconsistent states
- 2.4 Cleanup operations run even when errors occur (trap handlers)
- 2.5 Service state validation occurs before and after operations

### 3. As a developer, I want improved input validation so that invalid data is caught early with clear feedback

**Acceptance Criteria:**
- 3.1 All user inputs are validated before use
- 3.2 File paths are validated for existence and permissions
- 3.3 Configuration values are validated against expected formats
- 3.4 Validation failures provide specific guidance on correct format
- 3.5 Auth code format is validated if a pattern exists

### 4. As a maintainer, I want better testability so that I can verify changes don't break functionality

**Acceptance Criteria:**
- 4.1 External dependencies (systemctl, ipsec, sed) are abstracted
- 4.2 Functions can be tested independently
- 4.3 Side effects are isolated and clearly documented
- 4.4 Mock-friendly interfaces for system commands

### 5. As a user, I want consistent and informative logging so that I can troubleshoot issues effectively

**Acceptance Criteria:**
- 5.1 All operations log their start, progress, and completion
- 5.2 Log levels (INFO, WARNING, ERROR) are used appropriately
- 5.3 Timestamps are included in logs for debugging
- 5.4 Sensitive information (auth codes) is never logged
- 5.5 Log output is structured and parseable

### 6. As a developer, I want improved code organization so that the script is easier to navigate and extend

**Acceptance Criteria:**
- 6.1 Constants are defined at the top with clear naming
- 6.2 Functions are ordered logically (utilities first, then operations)
- 6.3 Magic numbers and strings are replaced with named constants
- 6.4 Related functionality is grouped together
- 6.5 Comments explain "why" not "what"

### 7. As a security-conscious user, I want secure handling of credentials so that sensitive data isn't exposed

**Acceptance Criteria:**
- 7.1 Auth codes are not echoed to terminal during input
- 7.2 Auth codes are not logged or displayed in error messages
- 7.3 File permissions on config files are validated
- 7.4 Temporary files (if any) are securely created and cleaned up
- 7.5 Command history doesn't capture sensitive parameters

### 8. As a user, I want idempotent operations so that running commands multiple times is safe

**Acceptance Criteria:**
- 8.1 Starting an already-running service succeeds gracefully
- 8.2 Stopping an already-stopped service succeeds gracefully
- 8.3 Adding existing DNS entries doesn't create duplicates
- 8.4 Operations check current state before making changes
- 8.5 Status commands never modify system state

## Code Quality Issues Identified

### Critical Issues
1. **Global mutable state**: `PROXY_IP` and `VPN_IP` are modified during execution
2. **Inconsistent error handling**: Some functions return error codes, others exit directly
3. **Mixed concerns**: Configuration detection mixed with execution logic
4. **No rollback mechanism**: Failed operations may leave system in inconsistent state

### Design Patterns to Apply
1. **Strategy Pattern**: For different proxy implementations (danted vs sockd)
2. **Command Pattern**: For encapsulating operations with undo capability
3. **Template Method**: For common service start/stop patterns
4. **Factory Pattern**: For creating service-specific configurations

### Best Practices Violations
1. **Readonly variables modified**: `PROXY_IP` declared as variable but should be computed
2. **Function side effects**: Functions modify global state and files
3. **Poor separation**: UI (prompts) mixed with business logic
4. **Hardcoded values**: DNS server, ports, retry counts scattered throughout
5. **No dry-run mode**: Can't preview changes without executing them

### Maintainability Issues
1. **Long functions**: `main()` has too many responsibilities
2. **Duplicate logic**: Service start/stop patterns repeated
3. **Poor naming**: `nameserver_add/del` could be more descriptive
4. **No documentation**: Function parameters and return values undocumented
5. **Magic numbers**: Retry counts, delays, attempt limits not explained

### Performance Opportunities
1. **Unnecessary sleeps**: Fixed delays could be replaced with polling
2. **Redundant checks**: Process status checked multiple times
3. **Sequential operations**: Some operations could be parallelized
4. **Inefficient IP parsing**: Multiple awk/cut pipes could be simplified

## Non-Functional Requirements

### Compatibility
- Must work on systems with bash 4.0+
- Must support both danted and sockd proxy servers
- Must work with systemd-based systems
- Must handle both IPv4 (current) and potentially IPv6 in future

### Performance
- Script startup time < 1 second
- Service operations complete within configured timeout
- IP address retrieval completes within 10 seconds or fails clearly

### Reliability
- All operations are atomic where possible
- Failed operations can be retried safely
- System state is validated before and after changes
- No orphaned processes or configuration changes

### Usability
- Clear, actionable error messages
- Progress indicators for long operations
- Consistent command-line interface
- Help text is comprehensive and accurate

## Out of Scope
- Replacing bash with another language
- Adding new features beyond current functionality
- Supporting non-systemd init systems
- GUI or web interface
- Configuration file format changes
- Multi-VPN connection support

## Success Metrics
- All existing functionality preserved (verified by manual testing)
- Code complexity reduced (measured by cyclomatic complexity)
- Test coverage > 80% for pure functions
- No shellcheck warnings or errors
- Documentation coverage for all public functions
