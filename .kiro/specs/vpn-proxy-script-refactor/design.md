# VPN Proxy Script Refactor - Design Document

## Architecture Overview

### Current Architecture Issues
```
┌─────────────────────────────────────────┐
│  Single Monolithic Script              │
│  - Mixed concerns                       │
│  - Global mutable state                 │
│  - Tight coupling                       │
│  - No abstraction layers                │
└─────────────────────────────────────────┘
```

### Proposed Architecture
```
┌─────────────────────────────────────────┐
│           Main Controller               │
│  - Argument parsing                     │
│  - Operation orchestration              │
│  - Error coordination                   │
└──────────────┬──────────────────────────┘
               │
    ┌──────────┴──────────┬──────────────┐
    │                     │              │
┌───▼────┐         ┌──────▼───┐    ┌────▼─────┐
│ VPN    │         │ Proxy    │    │ DNS      │
│ Service│         │ Service  │    │ Service  │
└───┬────┘         └──────┬───┘    └────┬─────┘
    │                     │              │
    └──────────┬──────────┴──────────────┘
               │
    ┌──────────▼──────────────────────────┐
    │     Service Abstraction Layer       │
    │  - Systemd operations               │
    │  - Process management               │
    │  - State validation                 │
    └──────────┬──────────────────────────┘
               │
    ┌──────────▼──────────────────────────┐
    │      Utility Layer                  │
    │  - Logging                          │
    │  - Validation                       │
    │  - Configuration                    │
    └─────────────────────────────────────┘
```

## Module Design

### 1. Configuration Module

**Purpose**: Centralize all configuration and constants

**Interface**:
```bash
# Configuration structure
declare -A CONFIG=(
    [VPN_PROCESS_NAME]="charon"
    [VPN_SECRET_FILE]="/etc/ipsec.secrets"
    [VPN_SERVICE_NAME]="strongswan-starter.service"
    [DNS_SERVER]="10.18.103.6"
    [RESOLV_CONF]="/etc/resolv.conf"
    [PROXY_PORT]="1080"
    [MAX_IP_ATTEMPTS]=9
    [RETRY_DELAY]=1
    [MAX_AUTH_ATTEMPTS]=3
    [IP_RETRY_TIMEOUT]=10
)

# Proxy configuration (detected at runtime)
declare -A PROXY_CONFIG

# Functions
config_init()           # Initialize and validate configuration
config_detect_proxy()   # Detect proxy type and populate PROXY_CONFIG
config_validate()       # Validate all configuration values
config_get(key)        # Get configuration value safely
```

**Design Decisions**:
- Use associative arrays for structured configuration
- Separate runtime-detected config from static config
- Validate configuration on initialization
- Provide safe accessor functions

### 2. Logging Module

**Purpose**: Provide consistent, structured logging

**Interface**:
```bash
# Log levels
declare -r LOG_LEVEL_DEBUG=0
declare -r LOG_LEVEL_INFO=1
declare -r LOG_LEVEL_WARNING=2
declare -r LOG_LEVEL_ERROR=3

# Functions
log_init([log_file])           # Initialize logging system
log_set_level(level)           # Set minimum log level
log_debug(message)             # Debug level logging
log_info(message)              # Info level logging
log_warning(message)           # Warning level logging
log_error(message)             # Error level logging
log_sanitize(message)          # Remove sensitive data from logs
```

**Design Decisions**:
- Add timestamps to all log entries
- Support optional file logging
- Sanitize sensitive data automatically
- Use consistent formatting
- Support log level filtering

### 3. Validation Module

**Purpose**: Centralize all input and state validation

**Interface**:
```bash
validate_ipv4(ip)                    # Validate IPv4 address format
validate_file_exists(path)           # Check file exists and is readable
validate_file_writable(path)         # Check file is writable
validate_command_exists(command)     # Check command is available
validate_service_name(service)       # Validate systemd service name
validate_port(port)                  # Validate port number
validate_auth_code(code)             # Validate auth code format (if applicable)
validate_dns_server(ip)              # Validate DNS server address
```

**Design Decisions**:
- Return 0 for success, 1 for failure
- Log validation failures with specific reasons
- Provide detailed error messages
- No side effects (pure validation)

### 4. Service Abstraction Layer

**Purpose**: Abstract systemd and process operations

**Interface**:
```bash
# Service operations
service_start(service_name)          # Start systemd service
service_stop(service_name)           # Stop systemd service
service_restart(service_name)        # Restart systemd service
service_status(service_name)         # Get service status
service_is_active(service_name)      # Check if service is active
service_is_enabled(service_name)     # Check if service is enabled

# Process operations
process_is_running(process_name)     # Check if process is running
process_get_pid(process_name)        # Get process PID
process_wait_for(process_name, timeout)  # Wait for process to start
process_wait_stop(process_name, timeout) # Wait for process to stop
```

**Design Decisions**:
- Wrap all systemctl commands
- Provide timeout support
- Return structured status information
- Handle errors consistently
- Support dry-run mode

### 5. VPN Service Module

**Purpose**: Manage VPN lifecycle and operations

**Interface**:
```bash
# VPN operations
vpn_init()                           # Initialize VPN module
vpn_start([auth_code])               # Start VPN service
vpn_stop()                           # Stop VPN service
vpn_restart([auth_code])             # Restart VPN service
vpn_status()                         # Get VPN status
vpn_get_ip()                         # Get VPN IP address
vpn_is_connected()                   # Check if VPN is connected
vpn_update_auth_code(auth_code)      # Update auth code in config
vpn_validate_connection()            # Validate VPN connection
```

**Design Decisions**:
- Encapsulate all VPN-specific logic
- Separate auth code management
- Provide connection validation
- Return structured status
- Support rollback on failure

### 6. Proxy Service Module

**Purpose**: Manage proxy lifecycle with strategy pattern

**Interface**:
```bash
# Proxy operations
proxy_init()                         # Initialize proxy module
proxy_start(bind_ip)                 # Start proxy service
proxy_stop()                         # Stop proxy service
proxy_restart(bind_ip)               # Restart proxy service
proxy_status()                       # Get proxy status
proxy_is_running()                   # Check if proxy is running
proxy_update_config(bind_ip)         # Update proxy configuration
proxy_validate_config()              # Validate proxy configuration
proxy_get_type()                     # Get proxy type (danted/sockd)
```

**Design Decisions**:
- Abstract differences between danted and sockd
- Use strategy pattern for proxy-specific operations
- Validate configuration before applying
- Support atomic configuration updates
- Provide rollback capability

### 7. DNS Service Module

**Purpose**: Manage DNS configuration

**Interface**:
```bash
# DNS operations
dns_init()                           # Initialize DNS module
dns_add_server(server_ip)            # Add DNS server
dns_remove_server(server_ip)         # Remove DNS server
dns_has_server(server_ip)            # Check if DNS server exists
dns_backup_config()                  # Backup resolv.conf
dns_restore_config()                 # Restore resolv.conf
dns_validate_config()                # Validate DNS configuration
```

**Design Decisions**:
- Backup before modifications
- Support rollback
- Validate changes after applying
- Handle concurrent modifications
- Idempotent operations

### 8. Operation Controller

**Purpose**: Orchestrate complex operations with error handling

**Interface**:
```bash
# High-level operations
operation_start_all([auth_code])     # Start VPN and proxy
operation_stop_all()                 # Stop VPN and proxy
operation_restart_vpn([auth_code])   # Restart VPN only
operation_restart_proxy()            # Restart proxy only
operation_status_all()               # Show all status
operation_rollback()                 # Rollback failed operation
```

**Design Decisions**:
- Coordinate multiple services
- Implement error recovery
- Support partial rollback
- Validate state transitions
- Log all operations

## Error Handling Strategy

### Error Categories

1. **Validation Errors**: Invalid input or configuration
   - Action: Fail fast with clear message
   - Recovery: None (user must fix input)

2. **Permission Errors**: Insufficient privileges
   - Action: Fail with permission guidance
   - Recovery: None (user must run with sudo)

3. **Service Errors**: Service fails to start/stop
   - Action: Retry with exponential backoff
   - Recovery: Rollback to previous state

4. **Network Errors**: VPN connection fails
   - Action: Retry with timeout
   - Recovery: Clean up partial configuration

5. **Configuration Errors**: Config file issues
   - Action: Restore from backup
   - Recovery: Automatic rollback

### Error Handling Implementation

```bash
# Global error handler
trap 'error_handler $? $LINENO' ERR
trap 'cleanup_handler' EXIT INT TERM

error_handler() {
    local exit_code=$1
    local line_number=$2
    
    log_error "Error occurred at line $line_number with exit code $exit_code"
    
    # Attempt rollback if in operation
    if [[ -n "${OPERATION_IN_PROGRESS:-}" ]]; then
        log_warning "Attempting rollback..."
        operation_rollback
    fi
    
    cleanup_handler
    exit "$exit_code"
}

cleanup_handler() {
    # Clean up temporary files
    # Restore backups if needed
    # Log cleanup actions
    :
}
```

### Rollback Strategy

```bash
# State tracking
declare -A OPERATION_STATE=(
    [vpn_was_running]=false
    [proxy_was_running]=false
    [dns_was_configured]=false
    [config_backup_path]=""
)

# Rollback implementation
operation_rollback() {
    log_info "Rolling back operation..."
    
    # Restore services to previous state
    if [[ "${OPERATION_STATE[vpn_was_running]}" == "false" ]]; then
        vpn_stop || log_warning "Failed to stop VPN during rollback"
    fi
    
    if [[ "${OPERATION_STATE[proxy_was_running]}" == "false" ]]; then
        proxy_stop || log_warning "Failed to stop proxy during rollback"
    fi
    
    # Restore DNS configuration
    if [[ -n "${OPERATION_STATE[config_backup_path]}" ]]; then
        dns_restore_config || log_warning "Failed to restore DNS config"
    fi
    
    log_info "Rollback completed"
}
```

## State Management

### State Tracking

```bash
# Service state structure
declare -A SERVICE_STATE=(
    [vpn_status]="unknown"
    [vpn_ip]=""
    [proxy_status]="unknown"
    [proxy_type]=""
    [dns_configured]="unknown"
)

# State management functions
state_capture()          # Capture current state
state_restore()          # Restore previous state
state_validate()         # Validate current state
state_compare()          # Compare two states
```

### State Transitions

```
VPN States: stopped → starting → running → stopping → stopped
Proxy States: stopped → starting → running → stopping → stopped
DNS States: not_configured → configuring → configured → removing → not_configured
```

## Security Improvements

### 1. Credential Handling

```bash
# Secure auth code input
get_auth_code_secure() {
    local auth_code
    local prompt="Enter VPN auth code: "
    
    # Disable echo
    read -rsp "$prompt" auth_code
    echo >&2  # New line after hidden input
    
    # Validate before returning
    if validate_auth_code "$auth_code"; then
        echo "$auth_code"
        return 0
    else
        log_error "Invalid auth code format"
        return 1
    fi
}

# Sanitize logs
log_sanitize() {
    local message="$1"
    # Replace anything that looks like an auth code
    echo "$message" | sed 's/[0-9]\{6,\}/******/g'
}
```

### 2. File Permission Validation

```bash
validate_secure_file() {
    local file="$1"
    local perms
    
    perms=$(stat -c '%a' "$file" 2>/dev/null)
    
    # Check if file is world-readable
    if [[ "${perms: -1}" != "0" ]]; then
        log_warning "File $file is world-readable (permissions: $perms)"
        return 1
    fi
    
    return 0
}
```

### 3. Command Injection Prevention

```bash
# Safe command execution
safe_execute() {
    local cmd="$1"
    shift
    local -a args=("$@")
    
    # Use array to prevent word splitting
    "$cmd" "${args[@]}"
}
```

## Testing Strategy

### Unit Testing Approach

```bash
# Test framework integration
# Use bats (Bash Automated Testing System)

# Example test structure
@test "validate_ipv4 accepts valid IPv4" {
    run validate_ipv4 "192.168.1.1"
    [ "$status" -eq 0 ]
}

@test "validate_ipv4 rejects invalid IPv4" {
    run validate_ipv4 "256.1.1.1"
    [ "$status" -eq 1 ]
}

@test "vpn_start with valid auth code succeeds" {
    # Mock systemctl
    systemctl() { echo "mocked"; return 0; }
    export -f systemctl
    
    run vpn_start "123456"
    [ "$status" -eq 0 ]
}
```

### Integration Testing

```bash
# Test complete workflows
@test "start_all operation completes successfully" {
    # Setup: ensure services are stopped
    operation_stop_all
    
    # Execute
    run operation_start_all "123456"
    
    # Verify
    [ "$status" -eq 0 ]
    [ "$(vpn_is_connected)" = "true" ]
    [ "$(proxy_is_running)" = "true" ]
}
```

### Mock Strategy

```bash
# Mock external dependencies for testing
mock_systemctl() {
    case "$1" in
        start)
            echo "Starting service..."
            return 0
            ;;
        stop)
            echo "Stopping service..."
            return 0
            ;;
        status)
            echo "active"
            return 0
            ;;
    esac
}

# Enable mocking
enable_mocks() {
    if [[ "${TESTING_MODE:-false}" == "true" ]]; then
        systemctl() { mock_systemctl "$@"; }
        export -f systemctl
    fi
}
```

## Performance Optimizations

### 1. Replace Fixed Sleeps with Polling

```bash
# Current approach (inefficient)
sleep 2

# Improved approach
wait_for_service() {
    local service="$1"
    local timeout="${2:-10}"
    local elapsed=0
    local interval=0.5
    
    while (( elapsed < timeout )); do
        if service_is_active "$service"; then
            return 0
        fi
        sleep "$interval"
        elapsed=$(awk "BEGIN {print $elapsed + $interval}")
    done
    
    return 1
}
```

### 2. Optimize IP Parsing

```bash
# Current approach (multiple pipes)
ip=$(sudo ipsec status | awk '/^ipsec-client/ && /===/ {getline; print $2}' | cut -d'/' -f1)

# Improved approach (single awk)
get_vpn_ip_optimized() {
    sudo ipsec status | awk '
        /^ipsec-client/ && /===/ {
            getline
            split($2, parts, "/")
            print parts[1]
            exit
        }
    '
}
```

### 3. Parallel Status Checks

```bash
# Check multiple services in parallel
check_all_status() {
    local vpn_status
    local proxy_status
    local dns_status
    
    # Run in background
    vpn_status=$(vpn_status 2>&1) &
    local vpn_pid=$!
    
    proxy_status=$(proxy_status 2>&1) &
    local proxy_pid=$!
    
    dns_status=$(dns_status 2>&1) &
    local dns_pid=$!
    
    # Wait for all
    wait "$vpn_pid" "$proxy_pid" "$dns_pid"
    
    # Display results
    echo "$vpn_status"
    echo "$proxy_status"
    echo "$dns_status"
}
```

## Refactoring Plan

### Phase 1: Foundation (No Functional Changes)
1. Extract configuration into module
2. Improve logging with timestamps
3. Add comprehensive validation functions
4. Add error handling infrastructure (traps)
5. Add state tracking

### Phase 2: Service Abstraction
1. Create service abstraction layer
2. Refactor VPN operations into module
3. Refactor proxy operations into module
4. Refactor DNS operations into module
5. Add rollback capability

### Phase 3: Controller Layer
1. Create operation controller
2. Implement complex workflows
3. Add state validation
4. Improve error recovery

### Phase 4: Polish
1. Add security improvements
2. Optimize performance
3. Add comprehensive comments
4. Create test suite
5. Update documentation

## Backward Compatibility

### Command-Line Interface
- All existing commands must work identically
- Same argument order and format
- Same output format (colors, messages)
- Same exit codes

### Configuration Files
- No changes to file locations
- No changes to file formats
- Backward compatible with existing configs

### Environment
- Same system requirements
- Same dependencies
- Same privilege requirements

## Documentation Requirements

### Code Documentation
- Function headers with purpose, parameters, return values
- Complex logic explained with comments
- Examples for non-obvious usage
- Error conditions documented

### User Documentation
- Updated usage examples
- Troubleshooting guide
- Common error messages and solutions
- Migration guide (if needed)

## Success Criteria

1. All existing functionality preserved
2. No shellcheck warnings
3. Test coverage > 80%
4. Reduced cyclomatic complexity
5. Improved error messages
6. Rollback capability working
7. Performance maintained or improved
8. Security improvements implemented
